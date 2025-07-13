import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

// --- DatabaseService Import ---
import 'package:myapp/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get the current authenticated user

/// Manages step tracking, point accumulation, and daily resets for the Steps4Perks app.
/// It integrates with the device's pedometer, SharedPreferences for local caching,
/// and DatabaseService for persistent storage in Firestore.
class StepTracker with ChangeNotifier {
  /// Constants
  static const int stepsPerPoint = 100;
  static const int maxDailySteps = 10000;
  static const int maxDailyPoints = 100; // Max points per day (10000 steps / 100 steps/point)
  // static const int giftCardThreshold = 2500; // Removed: No longer a single threshold for gift card
  static const int dailyRedemptionCap = 100; // NEW: Max points a user can redeem per day

  /// --- State Variables ---
  int _currentSteps = 0; // Steps taken today relative to baseline
  int _baseSteps = 0; // Pedometer's raw step count at the start of the day/session
  int _totalPoints = 0; // Accumulated total points across all days
  int _storedDailySteps = 0; // Last saved daily steps from SharedPreferences/Firestore
  bool _isNewDay = false; // Flag to indicate if a new day has started

  // Pedometer streams
  Stream<StepCount>? _stepCountStream;
  Stream<PedestrianStatus>? _pedestrianStatusStream;

  // Pedometer availability flag
  bool _isPedometerAvailable = false;

  // --- Streak State Variables ---
  int _currentStreak = 0; // Current consecutive daily goal achievement streak
  String _lastGoalAchievedDate = ''; // Date (YYYY-MM-DD) when the goal was last achieved

  // --- NEW: Daily Redemption State Variables ---
  int _dailyRedeemedPointsToday = 0; // Points already redeemed today
  String _lastRedemptionDate = ''; // Date (YYYY-MM-DD) of the last redemption transaction

  // --- Service Instances ---
  final DatabaseService _databaseService = DatabaseService();
  User? _currentUser; // Holds the current authenticated Firebase user

  /// Public Getters
  int get currentSteps => _currentSteps;
  int get totalPoints => _totalPoints;
  bool get isNewDay => _isNewDay;
  bool get isPedometerAvailable => _isPedometerAvailable;
  int get currentStreak => _currentStreak; // Public getter for streak
  int get dailyRedeemedPointsToday => _dailyRedeemedPointsToday; // NEW: Getter for points redeemed today

  /// Computed daily points (max 100)
  int get dailyPoints {
    final cappedSteps = _currentSteps.clamp(0, maxDailySteps);
    return (cappedSteps / stepsPerPoint).floor().clamp(0, maxDailyPoints);
  }

  /// Computed live total points (includes today's yet-unsaved new points)
  int get computedTotalPoints {
    final currentDailyPoints = (_currentSteps.clamp(0, maxDailySteps) ~/ stepsPerPoint).clamp(0, maxDailyPoints);
    final storedDailyPoints = (_storedDailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);
    final newPointsToday = currentDailyPoints - storedDailyPoints;
    return _totalPoints + (newPointsToday > 0 ? newPointsToday : 0);
  }

  /// NEW: Check if user can redeem points (based on total points and daily cap)
  bool get canRedeemPoints {
    final redeemableFromTotal = _totalPoints; // Points user has
    final remainingDailyCap = dailyRedemptionCap - _dailyRedeemedPointsToday; // Points left in daily cap

    // Can redeem if user has points AND there's space in the daily cap
    return redeemableFromTotal > 0 && remainingDailyCap > 0;
  }

  /// Constructor
  StepTracker() {
    _init();
    // Listen for Firebase authentication state changes.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _currentUser = user;
      if (user != null) {
        debugPrint('StepTracker: User authenticated: ${user.uid}. Loading data from Database.');
        _loadDataFromDatabase(); // Load/sync data when user logs in
      } else {
        debugPrint('StepTracker: User logged out or not authenticated. Resetting local state.');
        // Reset all local state if no user is authenticated
        _currentSteps = 0;
        _baseSteps = 0;
        _totalPoints = 0;
        _storedDailySteps = 0;
        _isNewDay = false;
        _currentStreak = 0;
        _lastGoalAchievedDate = '';
        _dailyRedeemedPointsToday = 0; // Reset daily redeemed points
        _lastRedemptionDate = ''; // Reset last redemption date
        notifyListeners();
      }
    });
  }

  /// Initializes the step tracker: requests permissions, loads local data,
  /// starts pedometer listening, and syncs with Firestore if user is authenticated.
  Future<void> _init() async {
    await _requestPermission();
    await _startListening();

    // Load initial data from SharedPreferences first for quick UI display.
    await _loadBaseline();
    await _loadPoints();

    // If user is already authenticated, trigger data load/sync from Firestore.
    if (_databaseService.currentUserId != null) {
      await _loadDataFromDatabase();
    }
  }

  /// Loads/Syncs user-specific data from Firestore Database.
  /// This method listens to real-time updates from Firestore for total points,
  /// daily stats, and user profile (for streak and redemption data).
  Future<void> _loadDataFromDatabase() async {
    if (_currentUser == null) {
      debugPrint('StepTracker: Cannot load from Database, user not authenticated.');
      return;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Listen to user profile for total points, streak, and daily redemption data
    _databaseService.getUserProfile().listen((profileData) {
      if (profileData != null) {
        final dbTotalPoints = profileData['totalPoints'] as int? ?? 0;
        final dbCurrentStreak = profileData['currentStreak'] as int? ?? 0;
        final dbLastGoalAchievedDate = profileData['lastGoalAchievedDate'] as String? ?? '';
        // --- NEW: Load daily redemption fields ---
        final dbDailyRedeemedPointsToday = profileData['dailyRedeemedPointsToday'] as int? ?? 0;
        final dbLastRedemptionDate = profileData['lastRedemptionDate'] as String? ?? '';

        bool changed = false;
        if (dbTotalPoints != _totalPoints) { _totalPoints = dbTotalPoints; changed = true; }
        if (dbCurrentStreak != _currentStreak) { _currentStreak = dbCurrentStreak; changed = true; }
        if (dbLastGoalAchievedDate != _lastGoalAchievedDate) { _lastGoalAchievedDate = dbLastGoalAchievedDate; changed = true; }

        // --- NEW: Reset daily redeemed points if it's a new day ---
        if (dbLastRedemptionDate != today) {
          // If the last redemption was not today, reset daily redeemed points
          if (_dailyRedeemedPointsToday != 0 || dbDailyRedeemedPointsToday != 0) {
            _dailyRedeemedPointsToday = 0;
            debugPrint('StepTracker: New day detected, daily redeemed points reset to 0.');
            changed = true;
          }
        } else {
          // If last redemption was today, load the value
          if (dbDailyRedeemedPointsToday != _dailyRedeemedPointsToday) {
            _dailyRedeemedPointsToday = dbDailyRedeemedPointsToday;
            debugPrint('StepTracker: Loaded daily redeemed points from Database: $_dailyRedeemedPointsToday');
            changed = true;
          }
        }
        _lastRedemptionDate = dbLastRedemptionDate; // Always update last redemption date

        if (changed) {
          debugPrint('StepTracker: Profile data loaded/synced from Database.');
          notifyListeners();
        }
      } else {
        // No profile data in DB, reset local state for these fields
        _totalPoints = 0;
        _currentStreak = 0;
        _lastGoalAchievedDate = '';
        _dailyRedeemedPointsToday = 0;
        _lastRedemptionDate = '';
        debugPrint('StepTracker: No user profile data found in Database. Resetting local profile state.');
        notifyListeners();
      }
    });

    // Listen to today's daily stats from Database
    _databaseService.getDailyStats(today).listen((dailyStats) {
      if (dailyStats != null) {
        final dbSteps = dailyStats['steps'] as int? ?? 0;
        if (dbSteps != _currentSteps || dbSteps != _storedDailySteps) {
          _currentSteps = dbSteps;
          _storedDailySteps = dbSteps;
          debugPrint('StepTracker: Loaded daily steps from Database: $_currentSteps');
          notifyListeners();
        }
      } else {
        debugPrint('StepTracker: No Database data for today. Resetting local daily step state.');
        _currentSteps = 0;
        _storedDailySteps = 0;
        notifyListeners();
      }
    });
  }


  /// Requests the 'activityRecognition' permission.
  /// Updates [_isPedometerAvailable] based on permission status.
  Future<void> _requestPermission() async {
    final status = await Permission.activityRecognition.request();
    if (status.isPermanentlyDenied) {
      debugPrint('Activity Recognition permission permanently denied. Guiding user to settings.');
      await openAppSettings();
    }
    _isPedometerAvailable = status.isGranted;
    if (!status.isGranted) {
      debugPrint('Activity Recognition permission not granted.');
    }
    notifyListeners();
  }

  /// Load base steps and daily state from SharedPreferences.
  /// Checks if a new day has started and resets daily steps if so.
  /// This is important for initial load and offline consistency.
  Future<void> _loadBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDate = prefs.getString('lastResetDate') ?? '';

    if (lastDate != today) {
      _isNewDay = true;
      _baseSteps = -1;
      _currentSteps = 0;
      _storedDailySteps = 0;
      await prefs.setInt('dailySteps', 0);
      await prefs.setString('lastResetDate', today);
    } else {
      _isNewDay = false;
      _baseSteps = prefs.getInt('baseSteps') ?? 0;
      _storedDailySteps = prefs.getInt('dailySteps') ?? 0;
      _currentSteps = _storedDailySteps;
    }
    notifyListeners();
  }

  /// Load persisted total points from SharedPreferences.
  /// This serves as a quick local cache. The Firestore stream will provide the definitive value.
  Future<void> _loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    _totalPoints = prefs.getInt('totalPoints') ?? 0;
    notifyListeners();
  }

  /// Resets the [_isNewDay] flag, typically called after the UI has acknowledged the new day.
  void clearNewDayFlag() {
    _isNewDay = false;
    notifyListeners();
  }

  /// Start tracking steps by listening to pedometer streams.
  /// This method conditionally starts listening based on device type (physical vs. emulator)
  /// and permission status.
  Future<void> _startListening() async {
    bool isPhysicalDevice = true;
    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      isPhysicalDevice = androidInfo.isPhysicalDevice;
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await DeviceInfoPlugin().iosInfo;
      isPhysicalDevice = iosInfo.isPhysicalDevice;
    }

    if (!isPhysicalDevice) {
      debugPrint('Running on emulator/simulator, pedometer not available.');
      _isPedometerAvailable = false;
      notifyListeners();
      return;
    }

    final status = await Permission.activityRecognition.status;
    if (!status.isGranted) {
      debugPrint('Pedometer cannot start: Activity Recognition permission not granted.');
      _isPedometerAvailable = false;
      notifyListeners();
      return;
    }

    _pedestrianStatusStream = Pedometer.pedestrianStatusStream;
    _pedestrianStatusStream?.listen(
      _onPedestrianStatusChanged,
      onError: _onPedestrianStatusError,
      cancelOnError: true,
    );

    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream?.listen(
      _onStepCount,
      onError: _onStepCountError,
      cancelOnError: true,
    );

    _isPedometerAvailable = true;
    notifyListeners();
  }

  /// Handle new step data received from the pedometer sensor.
  Future<void> _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (prefs.getString('lastResetDate') != today) {
      await _loadBaseline();
    }

    if (_baseSteps == -1) {
      _baseSteps = event.steps;
      await prefs.setString('lastResetDate', today);
      await prefs.setInt('baseSteps', _baseSteps);
      _currentSteps = 0;
    } else {
      _currentSteps = event.steps - _baseSteps;
      if (_currentSteps < 0) _currentSteps = 0;
    }

    await _updatePointsAndSaveToDatabase();
    notifyListeners();
  }

  /// Update point state and persist daily steps to SharedPreferences and Database.
  /// This method also handles the daily streak calculation and saving.
  Future<void> _updatePointsAndSaveToDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final cappedCurrentSteps = _currentSteps.clamp(0, maxDailySteps);

    final oldPointsFromStoredSteps = (_storedDailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);
    final newPointsFromCurrentSteps = (cappedCurrentSteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

    // --- Daily Goal Achievement Check & Streak Update Logic ---
    if (cappedCurrentSteps >= maxDailySteps) { // Goal met for today
      if (_lastGoalAchievedDate != today) { // Check if goal was already met today
        final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
        if (_lastGoalAchievedDate == yesterday) {
          _currentStreak++; // Consecutive day, increment streak
          debugPrint('StepTracker: Streak incremented to $_currentStreak');
        } else {
          _currentStreak = 1; // Not consecutive, start new streak (or first streak)
          debugPrint('StepTracker: Streak started at 1');
        }
        _lastGoalAchievedDate = today; // Update last achieved date to today

        // Save updated streak to Firestore
        if (_currentUser != null) {
          await _databaseService.saveUserProfile(
            name: _currentUser!.displayName ?? 'User',
            email: _currentUser!.email ?? 'no-email@example.com',
            currentStreak: _currentStreak,
            lastGoalAchievedDate: _lastGoalAchievedDate,
          );
        }
      }
    } else {
      // If daily goal is NOT met, and it's a new day since last goal achieved, reset streak.
      final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
      if (_lastGoalAchievedDate != '' && _lastGoalAchievedDate != today && _lastGoalAchievedDate != yesterday) {
        if (_currentStreak > 0) { // Only reset if there was an active streak
          _currentStreak = 0;
          debugPrint('StepTracker: Streak reset to 0 (missed a day).');
          if (_currentUser != null) {
            await _databaseService.saveUserProfile(
              name: _currentUser!.displayName ?? 'User',
              email: _currentUser!.email ?? 'no-email@example.com',
              currentStreak: _currentStreak,
              lastGoalAchievedDate: _lastGoalAchievedDate, // Keep last achieved date as is
            );
          }
        }
      }
    }
    // --- End Streak Logic ---


    if (newPointsFromCurrentSteps > oldPointsFromStoredSteps) {
      final gainedPoints = newPointsFromCurrentSteps - oldPointsFromStoredSteps;
      _totalPoints += gainedPoints; // Update local total points
      _storedDailySteps = cappedCurrentSteps; // Update local stored daily steps

      // --- Save to SharedPreferences (for quick local access/offline) ---
      await prefs.setInt('totalPoints', _totalPoints);
      await prefs.setInt('dailySteps', cappedCurrentSteps);

      // --- Save to Database ---
      if (_currentUser != null) {
        await _databaseService.saveUserProfile(
          name: _currentUser!.displayName ?? 'User',
          email: _currentUser!.email ?? 'no-email@example.com',
          totalPoints: _totalPoints,
        );
        await _databaseService.updateDailyStats(
          steps: cappedCurrentSteps,
          pointsEarnedToday: newPointsFromCurrentSteps, // Points gained just today
          totalPointsAccumulated: _totalPoints, // Current total accumulated points
          date: today,
        );
      }
    } else if (cappedCurrentSteps > _storedDailySteps) {
      // If steps increased but not enough for a new point, still update dailySteps
      _storedDailySteps = cappedCurrentSteps;
      await prefs.setInt('dailySteps', cappedCurrentSteps);
      // Also update in Database if steps increased, even without new points
      if (_currentUser != null) {
        await _databaseService.updateDailyStats(
          steps: cappedCurrentSteps,
          pointsEarnedToday: newPointsFromCurrentSteps, // Still pass current points for the day
          totalPointsAccumulated: _totalPoints,
          date: today,
        );
      }
    }
  }

  /// Add mock steps (for testing purposes, especially on emulators).
  /// Mock steps are only added if the real pedometer is not active.
  @override
  Future<void> addMockSteps(int stepsToAdd) async {
    if (!_isPedometerAvailable) { // Only allow mock steps if pedometer isn't active
      _currentSteps += stepsToAdd;
      await _updatePointsAndSaveToDatabase(); // Update points and save to Database
      notifyListeners(); // Notify UI of changes
    } else {
      debugPrint('Mock steps not added: Pedometer is active on this device.');
    }
  }

  /// NEW: Redeem points based on daily cap.
  /// This method is called after the user successfully watches an ad.
  /// Returns the number of points actually redeemed.
  Future<int> redeemPoints() async { // Changed return type to Future<int>
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int pointsToRedeem = 0;

    // Reset daily redeemed points if it's a new day since last redemption
    if (_lastRedemptionDate != today) {
      _dailyRedeemedPointsToday = 0;
      debugPrint('StepTracker: New day for redemption, daily cap reset.');
    }

    // Calculate how many points can be redeemed in this transaction
    final availablePoints = _totalPoints;
    final remainingDailyCap = dailyRedemptionCap - _dailyRedeemedPointsToday;

    pointsToRedeem = availablePoints.clamp(0, remainingDailyCap); // Clamp to ensure not negative or over cap

    if (pointsToRedeem > 0) {
      _totalPoints -= pointsToRedeem; // Deduct from total points
      _dailyRedeemedPointsToday += pointsToRedeem; // Add to today's redeemed count
      _lastRedemptionDate = today; // Update last redemption date to today

      // --- Save to SharedPreferences ---
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('totalPoints', _totalPoints);
      // Save daily redemption status to SharedPreferences as well for quick local consistency
      await prefs.setInt('dailyRedeemedPointsToday', _dailyRedeemedPointsToday);
      await prefs.setString('lastRedemptionDate', _lastRedemptionDate);

      // --- Save to Database ---
      if (_currentUser != null) {
        // Update total points and daily redemption status in user's profile
        await _databaseService.saveUserProfile(
          name: _currentUser!.displayName ?? 'User',
          email: _currentUser!.email ?? 'no-email@example.com',
          totalPoints: _totalPoints,
          dailyRedeemedPointsToday: _dailyRedeemedPointsToday,
          lastRedemptionDate: _lastRedemptionDate,
        );
        // Add a record of this specific redemption transaction
        await _databaseService.addRedeemedReward(
          rewardType: 'Points Redemption', // Generic type for daily point redemption
          value: pointsToRedeem.toDouble(), // Store the actual points redeemed
          status: 'fulfilled', // Assume immediate fulfillment for points
          giftCardCode: 'N/A', // No specific gift card code for small point redemptions
        );
      }
      debugPrint('StepTracker: Redeemed $pointsToRedeem points. Total remaining: $_totalPoints, Daily redeemed: $_dailyRedeemedPointsToday');
      notifyListeners(); // Notify UI of changes
    } else {
      debugPrint('StepTracker: No points available to redeem or daily cap reached.');
    }
    return pointsToRedeem;
  }

  /// Handle pedometer errors from the step count stream.
  void _onStepCountError(error) {
    debugPrint("Pedometer error: $error");
    _isPedometerAvailable = false; // Set flag to false if an error occurs
    notifyListeners(); // Notify UI that pedometer is not available
  }

  /// Handle pedometer errors from the pedestrian status stream.
  void _onPedestrianStatusError(error) {
    debugPrint("Pedestrian Status error: $error");
    _isPedometerAvailable = false; // Set flag to false if an error occurs
    notifyListeners();
  }

  /// Callback function for when pedestrian status changes.
  void _onPedestrianStatusChanged(PedestrianStatus event) {
    debugPrint('Pedestrian Status: ${event.status}');
  }
}
