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
  static const int giftCardThreshold = 2500; // Points needed to redeem a gift card

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

  // --- Service Instances ---
  final DatabaseService _databaseService = DatabaseService();
  User? _currentUser; // Holds the current authenticated Firebase user

  /// Public Getters
  int get currentSteps => _currentSteps;
  int get totalPoints => _totalPoints;
  bool get isNewDay => _isNewDay;
  bool get isPedometerAvailable => _isPedometerAvailable;
  int get currentStreak => _currentStreak; // Public getter for streak

  /// Computed daily points (max 100)
  int get dailyPoints {
    final cappedSteps = _currentSteps.clamp(0, maxDailySteps);
    return (cappedSteps / stepsPerPoint).floor().clamp(0, maxDailyPoints);
  }

  /// Computed live total points (includes today's yet-unsaved new points)
  /// This getter calculates total points including any points earned in the
  /// current session that haven't been persisted to _totalPoints yet.
  int get computedTotalPoints {
    final currentDailyPoints = (_currentSteps.clamp(0, maxDailySteps) ~/ stepsPerPoint).clamp(0, maxDailyPoints);
    final storedDailyPoints = (_storedDailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);
    final newPointsToday = currentDailyPoints - storedDailyPoints;
    return _totalPoints + (newPointsToday > 0 ? newPointsToday : 0);
  }

  /// Check if user can redeem a gift card
  bool get canRedeemGiftCard => _totalPoints >= giftCardThreshold;

  /// Constructor
  StepTracker() {
    _init();
    // Listen for Firebase authentication state changes.
    // This is crucial for loading/syncing user-specific data from Firestore
    // when a user logs in or out.
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
        notifyListeners();
      }
    });
  }

  /// Initializes the step tracker: requests permissions, loads local data,
  /// starts pedometer listening, and syncs with Firestore if user is authenticated.
  Future<void> _init() async {
    // Permission request and pedometer listening should happen regardless of Database data
    await _requestPermission();
    await _startListening(); // This will set _isPedometerAvailable

    // Load initial data from SharedPreferences first for quick UI display.
    // Firestore streams will then update these values if user is authenticated.
    await _loadBaseline();
    await _loadPoints();

    // If user is already authenticated (e.g., on hot restart or app re-open),
    // trigger data load/sync from Firestore.
    if (_databaseService.currentUserId != null) {
      await _loadDataFromDatabase();
    }
  }

  /// Loads/Syncs user-specific data from Firestore Database.
  /// This method listens to real-time updates from Firestore for total points,
  /// daily stats, and user profile (for streak data).
  Future<void> _loadDataFromDatabase() async {
    if (_currentUser == null) {
      debugPrint('StepTracker: Cannot load from Database, user not authenticated.');
      return;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Listen to user profile for total points and streak data
    _databaseService.getUserProfile().listen((profileData) {
      if (profileData != null) {
        final dbTotalPoints = profileData['totalPoints'] as int? ?? 0;
        final dbCurrentStreak = profileData['currentStreak'] as int? ?? 0;
        final dbLastGoalAchievedDate = profileData['lastGoalAchievedDate'] as String? ?? '';

        if (dbTotalPoints != _totalPoints) {
          _totalPoints = dbTotalPoints;
          debugPrint('StepTracker: Loaded total points from Database: $_totalPoints');
          notifyListeners();
        }
        if (dbCurrentStreak != _currentStreak || dbLastGoalAchievedDate != _lastGoalAchievedDate) {
          _currentStreak = dbCurrentStreak;
          _lastGoalAchievedDate = dbLastGoalAchievedDate;
          debugPrint('StepTracker: Loaded streak from Database: $_currentStreak days, last date: $_lastGoalAchievedDate');
          notifyListeners();
        }
      } else {
        // No profile data in DB, reset local state for these fields
        _totalPoints = 0;
        _currentStreak = 0;
        _lastGoalAchievedDate = '';
        debugPrint('StepTracker: No user profile data found in Database. Resetting local profile state.');
        notifyListeners();
      }
    });

    // Listen to today's daily stats from Database
    _databaseService.getDailyStats(today).listen((dailyStats) {
      if (dailyStats != null) {
        final dbSteps = dailyStats['steps'] as int? ?? 0;
        // The 'pointsEarnedToday' and 'totalPointsAccumulated' fields are also available in dailyStats
        // but _totalPoints is already updated by getUserProfile stream.

        // Sync local step state with Database data
        if (dbSteps != _currentSteps || dbSteps != _storedDailySteps) {
          _currentSteps = dbSteps;
          _storedDailySteps = dbSteps; // Ensure stored matches current from Database
          debugPrint('StepTracker: Loaded daily steps from Database: $_currentSteps');
          notifyListeners();
        }
      } else {
        // No Database data for today, ensure local daily state is reset for the day
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
      await openAppSettings(); // Open app settings for user to manually enable permission
    }
    // Set initial availability flag based on permission status
    _isPedometerAvailable = status.isGranted;
    if (!status.isGranted) {
      debugPrint('Activity Recognition permission not granted.');
    }
    notifyListeners(); // Notify UI about permission status change
  }

  /// Load base steps and daily state from SharedPreferences.
  /// Checks if a new day has started and resets daily steps if so.
  /// This is important for initial load and offline consistency.
  Future<void> _loadBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDate = prefs.getString('lastResetDate') ?? '';

    if (lastDate != today) {
      // It's a new day!
      _isNewDay = true;
      _baseSteps = -1; // Flag to indicate that _baseSteps needs to be set from the first step event
      _currentSteps = 0; // Reset current steps displayed for the new day
      _storedDailySteps = 0; // Reset stored daily steps
      await prefs.setInt('dailySteps', 0); // Reset daily steps in storage
      await prefs.setString('lastResetDate', today); // Update last reset date
    } else {
      // Same day as last recorded activity
      _isNewDay = false;
      _baseSteps = prefs.getInt('baseSteps') ?? 0; // Load previous base steps
      _storedDailySteps = prefs.getInt('dailySteps') ?? 0; // Load previous daily steps
      _currentSteps = _storedDailySteps; // Set current steps from stored for display
    }
    notifyListeners(); // Notify UI after loading baseline
  }

  /// Load persisted total points from SharedPreferences.
  /// This serves as a quick local cache. The Firestore stream will provide the definitive value.
  Future<void> _loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    _totalPoints = prefs.getInt('totalPoints') ?? 0;
    notifyListeners(); // Notify UI after loading points
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
    // Determine if the app is running on a physical device or an emulator/simulator.
    bool isPhysicalDevice = true;
    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      isPhysicalDevice = androidInfo.isPhysicalDevice;
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await DeviceInfoPlugin().iosInfo;
      isPhysicalDevice = iosInfo.isPhysicalDevice;
    }

    // If it's an emulator/simulator, set pedometer as unavailable and return.
    if (!isPhysicalDevice) {
      debugPrint('Running on emulator/simulator, pedometer not available.');
      _isPedometerAvailable = false;
      notifyListeners();
      return; // Stop here if not a physical device
    }

    // If it's a physical device, check permission status again before starting streams.
    final status = await Permission.activityRecognition.status;
    if (!status.isGranted) {
      debugPrint('Pedometer cannot start: Activity Recognition permission not granted.');
      _isPedometerAvailable = false;
      notifyListeners();
      return;
    }

    // --- Pedometer Stream Setup (only for physical devices with permission) ---

    // Listen to pedestrian status changes (e.g., walking/standing).
    _pedestrianStatusStream = Pedometer.pedestrianStatusStream;
    _pedestrianStatusStream?.listen(
      _onPedestrianStatusChanged,
      onError: _onPedestrianStatusError,
      cancelOnError: true, // Automatically stop listening if an error occurs
    );

    // Listen to step count changes.
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream?.listen(
      _onStepCount,
      onError: _onStepCountError,
      cancelOnError: true, // Automatically stop listening if an error occurs
    );

    // If we've reached this point, the pedometer should be available and listening.
    _isPedometerAvailable = true;
    notifyListeners();
  }

  /// Handle new step data received from the pedometer sensor.
  Future<void> _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Check if the date has changed since the app last recorded steps.
    // This handles cases where the app stays open overnight.
    if (prefs.getString('lastResetDate') != today) {
      await _loadBaseline(); // Trigger a full daily reset if date changed
      // After _loadBaseline, _baseSteps will be -1, and _currentSteps will be 0.
      // The next step event will set the new _baseSteps.
    }

    // If _baseSteps is -1, it means this is the first step event after a new day reset.
    if (_baseSteps == -1) {
      _baseSteps = event.steps; // Set the current event's steps as the new baseline
      await prefs.setString('lastResetDate', today); // Save current date as last reset date
      await prefs.setInt('baseSteps', _baseSteps); // Save the new baseline
      _currentSteps = 0; // Start daily steps from 0 for the new day
    } else {
      // Calculate daily steps relative to the baseline.
      _currentSteps = event.steps - _baseSteps;
      if (_currentSteps < 0) _currentSteps = 0; // Ensure steps don't go negative (can happen with sensor resets)
    }

    await _updatePointsAndSaveToDatabase(); // Update points and save to Database
    notifyListeners(); // Notify UI of updated steps and points
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
    // Check if the daily goal is met (e.g., 10,000 steps)
    if (cappedCurrentSteps >= maxDailySteps) { // Goal met for today
      // Check if goal was already met today (to avoid incrementing streak multiple times a day)
      if (_lastGoalAchievedDate != today) {
        // Check if it's a consecutive day (yesterday was the last goal date)
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
          await _databaseService.saveUserProfile( // Using saveUserProfile to update streak in profile
            name: _currentUser!.displayName ?? 'User', // Provide current user name
            email: _currentUser!.email ?? 'no-email@example.com', // Provide current user email
            currentStreak: _currentStreak,
            lastGoalAchievedDate: _lastGoalAchievedDate,
          );
        }
      }
    } else {
      // If daily goal is NOT met, and it's a new day since last goal achieved, reset streak.
      // This handles cases where user misses a day.
      final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
      // Check if _lastGoalAchievedDate is not empty, not today, and not yesterday.
      // This means a day was missed between the last goal and today.
      if (_lastGoalAchievedDate != '' && _lastGoalAchievedDate != today && _lastGoalAchievedDate != yesterday) {
        if (_currentStreak > 0) { // Only reset if there was an active streak
          _currentStreak = 0;
          debugPrint('StepTracker: Streak reset to 0 (missed a day).');
          if (_currentUser != null) {
            await _databaseService.saveUserProfile( // Using saveUserProfile to update streak in profile
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
        // Update total points in user's profile
        await _databaseService.saveUserProfile(
          name: _currentUser!.displayName ?? 'User',
          email: _currentUser!.email ?? 'no-email@example.com',
          totalPoints: _totalPoints,
        );
        // Update daily stats document
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

  /// Redeem gift card by deducting the [giftCardThreshold] from total points.
  @override
  Future<void> redeemGiftCard() async {
    if (_totalPoints >= giftCardThreshold) {
      _totalPoints -= giftCardThreshold; // Deduct points

      // --- Save to SharedPreferences ---
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('totalPoints', _totalPoints);

      // --- Save to Database ---
      if (_currentUser != null) {
        // Update total points in user's profile after redemption
        await _databaseService.saveUserProfile(
          name: _currentUser!.displayName ?? 'User',
          email: _currentUser!.email ?? 'no-email@example.com',
          totalPoints: _totalPoints,
        );
        // Add redeemed reward record to Database
        await _databaseService.addRedeemedReward(
          rewardType: 'Woolworths \$50 Gift Card', // Example reward
          value: 50.0,
          status: 'pending', // Initial status (e.g., waiting for fulfillment)
        );
      }

      notifyListeners();
    }
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
