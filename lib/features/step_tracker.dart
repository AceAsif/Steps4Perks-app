import 'dart:async';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:myapp/services/database_service.dart';
import 'package:myapp/services/device_service.dart';
import 'package:myapp/services/permission_service.dart';
import 'package:myapp/services/pedometer_service.dart';
import 'package:myapp/utils/streak_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

enum StepStatus {
  idle,
  syncing,
  synced,
  failed,
}

class StepTracker with ChangeNotifier {
  // --- Constants ---
  static const int stepsPerPoint = 100;
  static const int maxDailyPoints = 100; // Max points earnable from steps per day
  static const int dailyRedemptionCap = 2500; // Max points redeemable per day (for spending, not earning)

  // --- Internal State Variables ---
  int _rawSensorSteps = 0;      // Cumulative steps directly from the sensor/pedometer API
  int _dailySteps = 0;          // Steps counted for the current day (0-based for the day)
  int _dailyStepBaseline = 0;   // The _rawSensorSteps value at the start of the current day's counting
  int _totalPoints = 0;         // Overall accumulated points
  int _currentStreak = 0;
  bool _isPedometerAvailable = false;
  bool _isPhysicalDevice = true; // Determined by DeviceService
  bool _isNewDay = false;       // Flag set when a new calendar day is detected
  int _pointsRedeemedToday = 0; // Points redeemed today from the daily cap (for spending)

  bool _hasClaimedToday = false;    // Whether today's daily bonus points have been claimed
  String? _lastClaimCheckedDate;    // Last date we checked claim status from DB
  StepStatus _status = StepStatus.idle; // Sync status for UI feedback

  // --- Services ---
  final _deviceService = DeviceService();
  final _permissionService = PermissionService();
  final _pedometerService = PedometerService();
  final _streakManager = StreakManager();
  final _databaseService = DatabaseService();

  // --- Timers & Lifecycle ---
  Timer? _syncTimer;
  bool _isDisposed = false;

  // --- Constructor ---
  StepTracker() {
    _init();
  }

  // --- Public Getters for UI/External Access ---
  int get currentSteps => _dailySteps;
  int get totalPoints => _totalPoints;
  int get currentStreak => _currentStreak;
  bool get isPedometerAvailable => _isPedometerAvailable;
  bool get isNewDay => _isNewDay;
  bool get canRedeemPoints => (_totalPoints - _pointsRedeemedToday) >= dailyRedemptionCap; // For spending
  bool get isPhysicalDevice => _isPhysicalDevice;
  bool get hasClaimedToday => _hasClaimedToday; // For daily bonus claim
  String? get lastClaimCheckedDate => _lastClaimCheckedDate;
  StepStatus get status => _status;
  int get rawSensorSteps => _rawSensorSteps;
  // Calculate daily points earned based on _dailySteps, clamped to maxDailyPoints
  int get dailyPointsEarned => (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

  // --- Public Setters (if needed for external control/mocking in UI) ---
  void clearNewDayFlag() {
    _isNewDay = false;
    _safeNotifyListeners();
  }

  void setCurrentSteps(int steps) {
    if (_dailySteps != steps) {
      _dailySteps = steps;
      _safeNotifyListeners();
    }
  }

  void setCurrentStreak(int streak) {
    if (_currentStreak != streak) {
      _currentStreak = streak;
      _safeNotifyListeners();
    }
  }

  void setTotalPoints(int points) {
    if (_totalPoints != points) {
      _totalPoints = points;
      _safeNotifyListeners();
    }
  }

  void setClaimedToday(bool claimed) {
    if (_hasClaimedToday != claimed) {
      _hasClaimedToday = claimed;
      _safeNotifyListeners();
    }
  }

  // --- Initialization and Loading ---

  Future<void> _init() async {
    try {
      _isPhysicalDevice = await _deviceService.checkIfPhysicalDevice();
      _isPedometerAvailable = await _permissionService.requestActivityPermission();

      await _loadBaselineAndStreak(); // Combined loading for clarity
      await _loadTotalPoints();       // Load overall total points

      if (_isPhysicalDevice && _isPedometerAvailable) {
        debugPrint('✅ Starting pedometer service...');
        _pedometerService.startListening(
          onStepCount: _handleStepCount,
          onStepError: _handleStepError,
          onPedestrianStatusChanged: _handlePedStatus,
          onPedestrianStatusError: _handlePedStatusError,
        );
      } else {
        debugPrint('⚠️ Pedometer unavailable or permission denied/not a physical device. Daily steps will rely on stored data only.');
      }

      _startSyncTimer();
      _safeNotifyListeners(); // Notify initial state after all loading
    } catch (e, stackTrace) {
      debugPrint('❌ Initialization failed: $e');
      debugPrint('Stack Trace: $stackTrace');
      _status = StepStatus.failed;
      _safeNotifyListeners();
    }
  }

  Future<void> _loadBaselineAndStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
    final lastDate = prefs.getString('lastResetDate') ?? '';

    debugPrint('📊 Evaluating streak and loading baseline for $today...');

    if (lastDate != today) {
      debugPrint('🔄 New day detected. Resetting daily stats and evaluating streak.');
      _isNewDay = true;
      _dailySteps = 0; // Reset daily steps
      _dailyStepBaseline = 0; // Reset baseline, will be set by first sensor reading
      await prefs.setInt('dailySteps', 0);
      await prefs.setInt('dailyStepBaseline', 0);
      await prefs.remove('lastRecordedRawSensorSteps'); // Clear this for a clean start

      // Evaluate streak for the *previous* day's performance based on its stored steps
      _currentStreak = await _streakManager.evaluate(today, prefs, 0); // Streak manager should read prev day's steps from prefs/DB
      await prefs.setString('lastResetDate', today);
      await prefs.setInt('currentStreak', _currentStreak); // Save the new streak
      setClaimedToday(false); // New day, so not claimed yet
    } else {
      // Same day, load existing data
      _dailySteps = prefs.getInt('dailySteps') ?? 0;
      _dailyStepBaseline = prefs.getInt('dailyStepBaseline') ?? 0;
      _currentStreak = prefs.getInt('currentStreak') ?? 0;
      debugPrint('📅 Same day. Loaded dailySteps: $_dailySteps, baseline: $_dailyStepBaseline, streak: $_currentStreak');
    }

    await _checkIfClaimedToday(today); // Use internal method
  }

  Future<void> _loadTotalPoints() async {
    final prefs = await SharedPreferences.getInstance();
    _totalPoints = prefs.getInt('totalPoints') ?? 0;
    debugPrint('💰 Loaded total points: $_totalPoints');
  }

  // Helper for checkIfClaimedToday, internal to StepTracker
  Future<void> _checkIfClaimedToday(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final lastChecked = prefs.getString('lastClaimCheckedDate');

    if (lastChecked == date && _hasClaimedToday) return;

    try {
      final snapshot = await _databaseService.getDailyStatsOnce(date);
      // The 'redeemed' field should now specifically refer to the daily *bonus* claim
      final claimed = snapshot != null && snapshot['claimedDailyBonus'] == true;
      setClaimedToday(claimed);

      if (kDebugMode) {
        debugPrint('📦 Daily bonus claim check: $claimed (from DB)');
      }
    } catch (e, stack) {
      debugPrint('❌ Error checking daily bonus claim: $e\n$stack');
    }

    _lastClaimCheckedDate = date;
    await prefs.setString('lastClaimCheckedDate', date);
  }

  // --- Step Counting Logic (for actual Pedometer sensor) ---

  void _handleStepCount(int cumulativeStepsFromSensor) async {
    _rawSensorSteps = cumulativeStepsFromSensor;
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
    final lastDate = prefs.getString('lastResetDate') ?? '';

    debugPrint('👣 [Sensor] Incoming: $cumulativeStepsFromSensor. Last Reset Date: $lastDate. Today: $today');

    // Handle new day logic first
    if (today != lastDate) {
      debugPrint('🔄 [Sensor] Detected new day. Applying new day logic.');
      _isNewDay = true;
      _dailySteps = 0;
      _dailyStepBaseline = cumulativeStepsFromSensor; // Set baseline to current sensor reading
      await prefs.setInt('dailySteps', 0);
      await prefs.setInt('dailyStepBaseline', _dailyStepBaseline);
      await prefs.setString('lastResetDate', today);

      _currentStreak = await _streakManager.evaluate(today, prefs, 0);
      await prefs.setInt('currentStreak', _currentStreak);
      setClaimedToday(false); // New day, reset claimed status for daily bonus
      await _checkIfClaimedToday(today); // Re-check after new day logic
    } else {
      // Same Day Logic: Infer baseline if it hasn't been set or was reset
      if (_dailyStepBaseline == 0 && cumulativeStepsFromSensor > 0) {
        final lastSavedDailySteps = prefs.getInt('dailySteps') ?? 0;
        final lastRecordedRawSensorSteps = prefs.getInt('lastRecordedRawSensorSteps') ?? 0;

        if (lastRecordedRawSensorSteps > 0 && cumulativeStepsFromSensor >= lastRecordedRawSensorSteps) {
          _dailyStepBaseline = lastRecordedRawSensorSteps - lastSavedDailySteps;
          debugPrint('🎯 [Sensor] Inferred _dailyStepBaseline: $_dailyStepBaseline (from prefs data)');
        } else {
          _dailyStepBaseline = cumulativeStepsFromSensor - lastSavedDailySteps;
          debugPrint('⚠️ [Sensor] Fallback: Inferred _dailyStepBaseline: $_dailyStepBaseline (from current sensor and stored daily)');
        }
        await prefs.setInt('dailyStepBaseline', _dailyStepBaseline);
      } else if (_dailyStepBaseline == 0) {
        _dailyStepBaseline = prefs.getInt('dailyStepBaseline') ?? 0;
        if (_dailyStepBaseline == 0) {
          _dailyStepBaseline = cumulativeStepsFromSensor;
          await prefs.setInt('dailyStepBaseline', _dailyStepBaseline);
          debugPrint('🔄 [Sensor] Resetting _dailyStepBaseline to incoming sensor ($cumulativeStepsFromSensor) as it was 0.');
        }
      }
      _currentStreak = prefs.getInt('currentStreak') ?? 0; // Ensure streak is loaded
    }

    final int calculatedDailySteps = (cumulativeStepsFromSensor - _dailyStepBaseline).clamp(0, 10000000);

    if (calculatedDailySteps > _dailySteps) {
      debugPrint('✨ [Sensor] New steps detected: $calculatedDailySteps > $_dailySteps');
      _dailySteps = calculatedDailySteps;
      await prefs.setInt('lastRecordedRawSensorSteps', cumulativeStepsFromSensor);

      // Recalculate points based on new daily steps (points earned from activity)
      final oldPointsEarned = dailyPointsEarned;
      final newPointsEarned = (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

      if (newPointsEarned > oldPointsEarned) {
        // Only update _totalPoints from *step-based earnings* here
        _totalPoints += (newPointsEarned - oldPointsEarned);
        await prefs.setInt('totalPoints', _totalPoints);
        debugPrint('💰 [Sensor] Gained ${newPointsEarned - oldPointsEarned} points from steps. New total points: $_totalPoints');
      }
      await prefs.setInt('dailySteps', _dailySteps);
      _safeNotifyListeners();
    } else {
      debugPrint('🚫 [Sensor] No new steps for UI update. Calculated: $calculatedDailySteps, Current: $_dailySteps');
    }
  }

  // --- UI Data Retrieval ---

  Future<Map<String, dynamic>?> getDailyStatsForUI(String date) async {
    try {
      final data = await _databaseService.getDailyStatsOnce(date);
      debugPrint('📊 UI Data Request: Fetched daily stats for $date: ${data != null ? 'Found' : 'Not Found'}');
      return data;
    } catch (e, stackTrace) {
      debugPrint('❌ StepTracker.getDailyStatsForUI error: $e');
      debugPrint('Stack Trace: $stackTrace');
      return null;
    }
  }

  // --- Background Sync ---

  void _startSyncTimer() {
    int lastSyncedSteps = -1;
    int lastSyncedPoints = -1;
    bool lastSyncedClaimStatus = false;

    _syncTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      if (_isDisposed) return;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());

      // Only sync if daily steps, total points, or claim status have changed since last successful sync
      if (_dailySteps != lastSyncedSteps || _totalPoints != lastSyncedPoints || _hasClaimedToday != lastSyncedClaimStatus) {
        _status = StepStatus.syncing;
        _safeNotifyListeners();
        debugPrint('🔄 Initiating background sync: Daily Steps: $_dailySteps, Total Points: $_totalPoints, Claimed Today: $_hasClaimedToday');
        try {
          await _databaseService.saveStatsAndPoints(
            date: today,
            steps: _dailySteps,
            dailyPointsEarned: dailyPointsEarned,
            streak: _currentStreak,
            totalPoints: _totalPoints,
            claimedDailyBonus: _hasClaimedToday, // Include the daily bonus claim status
          );
          lastSyncedSteps = _dailySteps;
          lastSyncedPoints = _totalPoints;
          lastSyncedClaimStatus = _hasClaimedToday;
          _status = StepStatus.synced;
          debugPrint('✅ Background sync successful: Daily Steps: $lastSyncedSteps, Total Points: $lastSyncedPoints, Claimed Today: $lastSyncedClaimStatus');
        } catch (e, stackTrace) {
          _status = StepStatus.failed;
          debugPrint('❌ Background sync failed: $e');
          debugPrint('Stack Trace: $stackTrace');
        } finally {
          _safeNotifyListeners();
        }
      } else {
        debugPrint('✅ No changes to sync. Skipping background sync.');
      }
    });
  }

  // --- Point Earning Logic for Daily Bonus Claim ---
  Future<void> claimDailyBonusPoints() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());

    if (_hasClaimedToday) {
      debugPrint('🚫 Already claimed daily bonus points for today.');
      return;
    }

    // Ensure the user has earned the maximum daily points from steps to be eligible for the bonus
    if (dailyPointsEarned < maxDailyPoints) {
      debugPrint('🚫 Cannot claim daily bonus. Need to earn ${maxDailyPoints - dailyPointsEarned} more points from steps to reach $maxDailyPoints.');
      return;
    }

    try {
      _totalPoints += maxDailyPoints; // Add the 100 bonus points
      setClaimedToday(true); // Mark as claimed for today

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('totalPoints', _totalPoints);

      // Update Firestore to reflect the claim status and new total points
      await _databaseService.updateDailyClaimStatus(
        date: today,
        claimed: true,
        totalPoints: _totalPoints, // Pass the NEW total after bonus
      );

      debugPrint('✅ Successfully claimed $maxDailyPoints daily bonus points! New total: $_totalPoints');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to claim daily bonus points: $e');
      debugPrint('Stack Trace: $stackTrace');
      // Revert local changes if database update fails
      _totalPoints -= maxDailyPoints;
      setClaimedToday(false);
    } finally {
      _safeNotifyListeners();
    }
  }

  // --- Point Redemption Logic (for spending accumulated points) ---
  // This method is for spending points, not earning them.
  Future<int> redeemPoints() async {
    if (!canRedeemPoints) {
      debugPrint('🚫 Cannot redeem points: Insufficient points or daily cap reached. Total: $_totalPoints, Redeemed Today: $_pointsRedeemedToday');
      return 0;
    }

    try {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
      final redeemedAmount = dailyRedemptionCap; // This is the amount you can redeem at once

      // Deduct locally first
      _pointsRedeemedToday += redeemedAmount;
      _totalPoints -= redeemedAmount;

      debugPrint('💰 Attempting to redeem $redeemedAmount points. New local total: $_totalPoints');

      // Sync the redemption status and new total points to Firestore atomically
      final success = await _databaseService.redeemDailyPoints(
        date: date,
        pointsToRedeem: redeemedAmount,
        currentTotalPoints: _totalPoints, // Pass the NEW total after local deduction
      );

      if (success) {
        // Persist local total points to SharedPreferences after successful DB sync
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('totalPoints', _totalPoints);
        // Do NOT set setClaimedToday(true) here, as this is for spending, not the daily bonus.
        debugPrint('✅ Points redeemed successfully for $date. Total points: $_totalPoints');
        return redeemedAmount;
      } else {
        // Revert local changes if database update failed
        _totalPoints += redeemedAmount;
        _pointsRedeemedToday -= redeemedAmount;
        debugPrint('❌ Redemption failed to sync to database, reverting local changes. Total points restored to: $_totalPoints');
        return 0;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Redeem failed: $e');
      debugPrint('Stack Trace: $stackTrace');
      return 0;
    } finally {
      _safeNotifyListeners();
    }
  }

  // --- Manual Reset ---

  Future<void> resetSteps() async {
    debugPrint('🔁 Manually resetting steps and related data...');
    _dailySteps = 0;
    _dailyStepBaseline = 0;
    _rawSensorSteps = 0;
    _pointsRedeemedToday = 0; // Reset daily redemption status too

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dailySteps', 0);
    await prefs.setInt('dailyStepBaseline', 0);
    await prefs.remove('lastRecordedRawSensorSteps');
    // For a full user data wipe, you might also want to reset totalPoints:
    // await prefs.setInt('totalPoints', 0);
    // _totalPoints = 0;

    setClaimedToday(false); // Clear claimed status for daily bonus
    _isNewDay = true;

    _safeNotifyListeners();
    debugPrint('✅ Steps manually reset to 0 (and baseline/redeemed status).');
  }

  // --- Pedometer Error & Status Handlers ---

  void _handleStepError(dynamic error) {
    debugPrint('Step count error: $error');
    _isPedometerAvailable = false;
    _safeNotifyListeners();
  }

  void _handlePedStatus(String status) {
    debugPrint('🚶 Pedestrian status: $status');
  }

  void _handlePedStatusError(dynamic error) {
    debugPrint('Pedestrian status error: $error');
    _isPedometerAvailable = false;
    _safeNotifyListeners();
  }

  // --- External Mock Step Control (Debug Only) ---

  Future<void> addMockSteps(int stepsToAdd) async {
    if (kDebugMode) {
      _dailySteps += stepsToAdd;
      debugPrint('📈 [Mock] Added $stepsToAdd steps. New _dailySteps: $_dailySteps');

      final oldPointsEarned = dailyPointsEarned;
      final newPointsEarned = (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

      if (newPointsEarned > oldPointsEarned) {
        _totalPoints += (newPointsEarned - oldPointsEarned);
        await SharedPreferences.getInstance().then((prefs) {
          prefs.setInt('totalPoints', _totalPoints);
        });
        debugPrint('💰 [Mock] Gained ${newPointsEarned - oldPointsEarned} points. Total points: $_totalPoints');
      }

      await SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('dailySteps', _dailySteps);
      });

      _safeNotifyListeners();

      // Immediately sync mock steps to database for visual verification in Firestore
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
      try {
        await _databaseService.saveStatsAndPoints(
          date: today,
          steps: _dailySteps,
          dailyPointsEarned: dailyPointsEarned,
          streak: _currentStreak,
          totalPoints: _totalPoints,
          claimedDailyBonus: _hasClaimedToday, // Ensure this is also synced
        );
        debugPrint('✅ [Mock] Steps synced to database for verification.');
      } catch (e, stackTrace) {
        debugPrint('❌ [Mock] Failed to sync mock steps to database: $e');
        debugPrint('Stack Trace: $stackTrace');
      }
    } else {
      debugPrint('🚫 Mock steps are only allowed in debug mode. Current mode: ${kReleaseMode ? "Release" : "Profile"}');
    }
  }

  // --- Utilities ---

  void _safeNotifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _isDisposed = true;
    super.dispose();
  }
}