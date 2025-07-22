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
  static const int dailyRedemptionCap = 2500; // Max points redeemable per day

  // --- Internal State Variables ---
  int _rawSensorSteps = 0;      // Cumulative steps directly from the sensor/pedometer API
  int _dailySteps = 0;          // Steps counted for the current day (0-based for the day)
  int _dailyStepBaseline = 0;   // The _rawSensorSteps value at the start of the current day's counting
  int _totalPoints = 0;         // Overall accumulated points
  int _currentStreak = 0;
  bool _isPedometerAvailable = false;
  bool _isPhysicalDevice = true; // Determined by DeviceService
  bool _isNewDay = false;       // Flag set when a new calendar day is detected
  int _pointsRedeemedToday = 0; // Points redeemed today from the daily cap

  bool _hasClaimedToday = false;    // Whether today's daily points have been claimed
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
  bool get canRedeemPoints => (_totalPoints - _pointsRedeemedToday) >= dailyRedemptionCap;
  bool get isPhysicalDevice => _isPhysicalDevice;
  bool get hasClaimedToday => _hasClaimedToday;
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

  // Note: setCurrentSteps directly sets _dailySteps.
  // This is primarily useful for initial loading or direct mock step injection.
  void setCurrentSteps(int steps) {
    if (_dailySteps != steps) { // Only update if value changes
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
      final claimed = snapshot != null && snapshot['redeemed'] == true;
      setClaimedToday(claimed);

      if (kDebugMode) {
        debugPrint('📦 Claim check: $claimed (from DB)');
      }
    } catch (e, stack) {
      debugPrint('❌ Error checking claim: $e\n$stack');
    }

    _lastClaimCheckedDate = date;
    await prefs.setString('lastClaimCheckedDate', date);
  }


  // --- Step Counting Logic (for actual Pedometer sensor) ---

  void _handleStepCount(int cumulativeStepsFromSensor) async {
    // 1. Assign the incoming sensor value to the class member
    _rawSensorSteps = cumulativeStepsFromSensor; // <-- ADD THIS LINE
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
      setClaimedToday(false); // New day, reset claimed status
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
          // Fallback for cases where historical raw data is unreliable or first sensor reading on a fresh start
          _dailyStepBaseline = cumulativeStepsFromSensor - lastSavedDailySteps;
          debugPrint('⚠️ [Sensor] Fallback: Inferred _dailyStepBaseline: $_dailyStepBaseline (from current sensor and stored daily)');
        }
        await prefs.setInt('dailyStepBaseline', _dailyStepBaseline);
      } else if (_dailyStepBaseline == 0) {
        // This case handles initial 0 step readings or situations where baseline wasn't loaded correctly
        _dailyStepBaseline = prefs.getInt('dailyStepBaseline') ?? 0;
        if (_dailyStepBaseline == 0) { // If still 0, set to current sensor reading (only if sensor sends 0)
          _dailyStepBaseline = cumulativeStepsFromSensor;
          await prefs.setInt('dailyStepBaseline', _dailyStepBaseline);
          debugPrint('🔄 [Sensor] Resetting _dailyStepBaseline to incoming sensor ($cumulativeStepsFromSensor) as it was 0.');
        }
      }
      _currentStreak = prefs.getInt('currentStreak') ?? 0; // Ensure streak is loaded
    }

    final int calculatedDailySteps = (cumulativeStepsFromSensor - _dailyStepBaseline).clamp(0, 10000000); // Max steps for safety

    // Only update if steps have actually increased to avoid unnecessary UI updates or saving identical values
    if (calculatedDailySteps > _dailySteps) {
      debugPrint('✨ [Sensor] New steps detected: $calculatedDailySteps > $_dailySteps');
      _dailySteps = calculatedDailySteps;
      await prefs.setInt('lastRecordedRawSensorSteps', cumulativeStepsFromSensor); // Always save latest raw sensor for baseline inference

      // Recalculate points based on new daily steps
      final oldPointsEarned = dailyPointsEarned;
      final newPointsEarned = (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

      if (newPointsEarned > oldPointsEarned) {
        _totalPoints += (newPointsEarned - oldPointsEarned);
        await prefs.setInt('totalPoints', _totalPoints);
        debugPrint('💰 [Sensor] Gained ${newPointsEarned - oldPointsEarned} points. New total points: $_totalPoints');
      }
      await prefs.setInt('dailySteps', _dailySteps); // Save the calculated daily steps to SharedPreferences
      _safeNotifyListeners(); // Notify UI to update
    } else {
      debugPrint('🚫 [Sensor] No new steps for UI update. Calculated: $calculatedDailySteps, Current: $_dailySteps');
    }
  }

  // --- UI Data Retrieval ---

  Future<Map<String, dynamic>?> getDailyStatsForUI(String date) async {
    try {
      // Calls DatabaseService for a single read
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
    // These are local variables, so no leading underscore needed
    int lastSyncedSteps = -1;
    int lastSyncedPoints = -1;

    _syncTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      if (_isDisposed) return;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());

      // Only sync if daily steps or total points have changed since last successful sync
      if (_dailySteps != lastSyncedSteps || _totalPoints != lastSyncedPoints) {
        _status = StepStatus.syncing;
        _safeNotifyListeners();
        debugPrint('🔄 Initiating background sync: Daily Steps: $_dailySteps, Total Points: $_totalPoints');
        try {
          await _databaseService.saveStatsAndPoints(
            date: today,
            steps: _dailySteps,
            dailyPointsEarned: dailyPointsEarned, // Use the getter
            streak: _currentStreak,
            totalPoints: _totalPoints,
          );
          lastSyncedSteps = _dailySteps;
          lastSyncedPoints = _totalPoints;
          _status = StepStatus.synced;
          debugPrint('✅ Background sync successful: Daily Steps: $lastSyncedSteps, Total Points: $lastSyncedPoints');
        } catch (e, stackTrace) {
          _status = StepStatus.failed;
          debugPrint('❌ Background sync failed: $e');
          debugPrint('Stack Trace: $stackTrace');
        } finally {
          _safeNotifyListeners(); // Always notify listeners after sync attempt
        }
      } else {
        debugPrint('✅ No changes to sync. Skipping background sync.');
      }
    });
  }

  // --- Point Redemption Logic ---

  Future<int> redeemPoints() async {
    if (!canRedeemPoints) {
      debugPrint('🚫 Cannot redeem points: Insufficient points or daily cap reached. Total: $_totalPoints, Redeemed Today: $_pointsRedeemedToday');
      return 0;
    }

    try {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
      final redeemedAmount = dailyRedemptionCap;

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
        setClaimedToday(true); // Mark as claimed for today via setter
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
      _safeNotifyListeners(); // Ensure UI updates after any redemption attempt
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
    await prefs.remove('lastRecordedRawSensorSteps'); // Clear this for a fresh start
    // Optionally also reset points related to reset if this is a full user data wipe
    // await prefs.setInt('totalPoints', 0);
    // _totalPoints = 0;

    setClaimedToday(false); // Clear claimed status
    _isNewDay = true; // Force new day detection on next _handleStepCount if desired

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

  // Note: This method is specifically for adding "fake" steps for development.
  // It bypasses the complexities of actual sensor baseline tracking.
  // Ensure the UI button calling this is also hidden in release builds.
  // In `homepage.dart`, use `if (kDebugMode)` for the _buildEmulatorControls.
  // The 'isPhysicalDevice' check in StepTracker's 'isPhysicalDevice' getter
  // is still valid for showing/hiding emulator UI in general.
  // This addMockSteps will work on both emulator and physical device IF kDebugMode is true.
  Future<void> addMockSteps(int stepsToAdd) async {
    if (kDebugMode) { // Ensures this is strictly debug-only
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