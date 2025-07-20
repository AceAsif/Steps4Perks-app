import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:myapp/services/database_service.dart';
import 'package:myapp/services/device_service.dart';
import 'package:myapp/services/permission_service.dart';
import 'package:myapp/services/pedometer_service.dart';
import 'package:myapp/utils/streak_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class StepTracker with ChangeNotifier {
  static const int stepsPerPoint = 100;
  static const int maxDailyPoints = 100;
  static const int dailyRedemptionCap = 2500;

  int _rawSensorSteps = 0; // Renamed from _currentSteps to clarify it's the raw cumulative sensor value
  int _dailySteps = 0; // This will be the actual daily steps shown to the user
  int _dailyStepBaseline = 0; // The cumulative steps at the start of the current day/session
  int _totalPoints = 0;
  int _currentStreak = 0;
  bool _isPedometerAvailable = false;
  bool _isPhysicalDevice = true;
  bool _isNewDay = false;
  int pointsRedeemedToday = 0;

  bool _hasClaimedToday = false;
  bool get hasClaimedToday => _hasClaimedToday;
  String? _lastClaimCheckedDate;
  String? get lastClaimCheckedDate => _lastClaimCheckedDate;

  final _deviceService = DeviceService();
  final _permissionService = PermissionService();
  final _pedometerService = PedometerService();
  final _streakManager = StreakManager();
  final _databaseService = DatabaseService();

  DatabaseService get databaseService => _databaseService;

  Timer? _syncTimer;
  bool _isDisposed = false;

  StepTracker() {
    _init();
  }

  // Expose _dailySteps to the UI as currentSteps
  int get currentSteps => _dailySteps;
  int get totalPoints => _totalPoints;
  int get currentStreak => _currentStreak;
  bool get isPedometerAvailable => _isPedometerAvailable;
  bool get isNewDay => _isNewDay;
  bool get canRedeemPoints => (_totalPoints - pointsRedeemedToday) >= dailyRedemptionCap;
  bool get isPhysicalDevice => _isPhysicalDevice;
  // Calculate dailyPoints based on _dailySteps
  int get dailyPoints => (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

  void clearNewDayFlag() {
    _isNewDay = false;
    _safeNotifyListeners();
  }

  // This setter should update _dailySteps if manually setting (e.g., mock steps)
  void setCurrentSteps(int steps) {
    _dailySteps = steps;
    notifyListeners();
  }

  void setCurrentStreak(int streak) {
    _currentStreak = streak;
    notifyListeners();
  }

  void setTotalPoints(int points) {
    _totalPoints = points;
    notifyListeners();
  }

  void setClaimedToday(bool claimed) {
    _hasClaimedToday = claimed;
    notifyListeners();
  }

  Future<void> checkIfClaimedToday(String date, DatabaseService databaseService) async {
    final prefs = await SharedPreferences.getInstance();
    final lastChecked = prefs.getString('lastClaimCheckedDate') ?? '';

    // If it's a new day since the last check, reset claim status
    if (lastChecked != date) {
      _hasClaimedToday = false;
      _lastClaimCheckedDate = date;
      await prefs.setString('lastClaimCheckedDate', date);
      _safeNotifyListeners(); // Notify as claim status might change
    }

    try {
      final snapshot = await databaseService.getDailyStatsStream(date).first;
      if (snapshot != null && snapshot['redeemed'] == true) {
        _hasClaimedToday = true;
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('❌ checkIfClaimedToday: $e');
    }
  }

  Future<bool> claimDailyPoints(String date) async {
    final success = await _databaseService.redeemDailyPoints(date: date);
    if (success) {
      _hasClaimedToday = true;
      _safeNotifyListeners();
    }
    return success;
  }

  Future<void> _init() async {
    try {
      _isPhysicalDevice = await _deviceService.checkIfPhysicalDevice();
      _isPedometerAvailable = await _permissionService.requestActivityPermission();

      await _loadBaseline();
      await _loadPoints();

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
        // Removed _handleStepCount(_currentSteps); as _currentSteps is 0 here and doesn't
        // represent the sensor data for non-physical devices. _loadBaseline handles initial state.
      }

      _startSyncTimer();
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('❌ Initialization failed: $e');
    }
  }

  Future<void> _loadBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
    final lastDate = prefs.getString('lastResetDate') ?? '';

    debugPrint('📊 Evaluating streak and loading baseline...');
    debugPrint('Today: $today');
    debugPrint('Last goal date: ${prefs.getString('lastGoalDate') ?? 'N/A'}');
    debugPrint('Current streak: ${prefs.getInt('currentStreak') ?? 0}');

    if (lastDate != today) {
      debugPrint('🔄 New day detected in _loadBaseline. Resetting daily stats.');
      _isNewDay = true;
      _dailySteps = 0; // Reset daily steps for the new day
      _dailyStepBaseline = 0; // Will be set by the first _handleStepCount for the day
      await prefs.setInt('dailySteps', 0); // Store 0 for daily steps
      await prefs.setInt('dailyStepBaseline', 0); // Reset baseline in storage
      await prefs.remove('lastRecordedRawSensorSteps'); // Clear last raw sensor steps for a clean start

      // Evaluate streak for the previous day. Pass _storedDailySteps for yesterday's count.
      // If lastDate was present and it's a new day, yesterday's steps would be _storedDailySteps.
      // However, the log indicates a streak reset because "goal not met yesterday (2025-07-20)".
      // This means evaluate should consider the steps from `lastDate` if available.
      // For simplicity, let's assume `_streakManager.evaluate` takes care of loading yesterday's steps.
      _currentStreak = await _streakManager.evaluate(today, prefs, 0); // Pass 0 as current daily steps, streak manager should read yesterday's.

      await prefs.setString('lastResetDate', today);
      await prefs.setInt('currentStreak', _currentStreak); // Save the new streak
    } else {
      // It's the same day, load previously stored values
      _dailySteps = prefs.getInt('dailySteps') ?? 0;
      _dailyStepBaseline = prefs.getInt('dailyStepBaseline') ?? 0;
      _currentStreak = prefs.getInt('currentStreak') ?? 0;
      debugPrint('📅 Same day in _loadBaseline. Loaded dailySteps: $_dailySteps, baseline: $_dailyStepBaseline');
    }

    await checkIfClaimedToday(today, _databaseService);
    _safeNotifyListeners(); // Notify after loading baseline and claim status
  }

  Future<void> _loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    _totalPoints = prefs.getInt('totalPoints') ?? 0;
    _safeNotifyListeners();
  }

  void _handleStepCount(int cumulativeStepsFromSensor) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
    final lastDate = prefs.getString('lastResetDate') ?? '';

    debugPrint('📅 Today: $today, Last Reset: $lastDate, Incoming Steps (Sensor): $cumulativeStepsFromSensor');

    // Handle new day logic first, as this affects how we calculate daily steps.
    if (today != lastDate) {
      debugPrint('🔄 Detected new day in _handleStepCount. Resetting and setting new baseline.');
      _isNewDay = true;
      _dailySteps = 0; // Reset daily steps for the new day
      _dailyStepBaseline = cumulativeStepsFromSensor; // Set the current sensor reading as the new baseline
      await prefs.setInt('dailySteps', 0); // Store 0 for daily steps
      await prefs.setInt('dailyStepBaseline', _dailyStepBaseline); // Store the new baseline
      await prefs.setString('lastResetDate', today);

      // Re-evaluate streak for the new day, considering yesterday's goal was not met implicitly by new day logic
      _currentStreak = await _streakManager.evaluate(today, prefs, 0); // Pass 0 as current daily steps, streak manager handles yesterday's.
      await prefs.setInt('currentStreak', _currentStreak);
      await checkIfClaimedToday(today, _databaseService);
    } else {
      // It's the same day. Ensure baseline is loaded or set from previous session.
      // This is crucial if the app was closed and reopened on the same day.
      if (_dailyStepBaseline == 0 && cumulativeStepsFromSensor > 0) {
        // If baseline is 0 but we're getting steps, it means the app just started
        // and it's the same day. We need to fetch the last saved daily steps
        // and infer the baseline from that.
        final lastSavedDailySteps = prefs.getInt('dailySteps') ?? 0;
        final lastRecordedRawSensorSteps = prefs.getInt('lastRecordedRawSensorSteps') ?? 0;

        if (lastRecordedRawSensorSteps > 0 && cumulativeStepsFromSensor >= lastRecordedRawSensorSteps) {
          // If we have a last recorded sensor step, use it to calculate baseline
          _dailyStepBaseline = lastRecordedRawSensorSteps - lastSavedDailySteps;
          debugPrint('🎯 Inferred _dailyStepBaseline: $_dailyStepBaseline (from lastRecordedRawSensorSteps and lastSavedDailySteps)');
        } else {
          // Fallback: If no good last recorded sensor steps, assume current incoming steps minus current _dailySteps
          // This might not be perfectly accurate if steps were taken while app was closed.
          _dailyStepBaseline = cumulativeStepsFromSensor - (prefs.getInt('dailySteps') ?? 0);
          debugPrint('⚠️ Fallback: Inferred _dailyStepBaseline: $_dailyStepBaseline (from incomingSensorSteps and stored daily steps)');
        }
        await prefs.setInt('dailyStepBaseline', _dailyStepBaseline);
      } else if (_dailyStepBaseline == 0) {
          // This case could happen if the app starts fresh on a new day and gets 0 steps initially.
          // It's safer to set baseline to current incoming steps if it's 0 and incoming is also 0.
          // Or if _dailyStepBaseline was never loaded correctly.
          _dailyStepBaseline = prefs.getInt('dailyStepBaseline') ?? 0;
          if (_dailyStepBaseline == 0) {
             _dailyStepBaseline = cumulativeStepsFromSensor; // If still 0, use current sensor reading as baseline
             await prefs.setInt('dailyStepBaseline', _dailyStepBaseline);
             debugPrint('🔄 Resetting _dailyStepBaseline to incomingSensorSteps ($cumulativeStepsFromSensor) as it was 0.');
          }
      }
      _currentStreak = prefs.getInt('currentStreak') ?? 0; // Load existing streak for the day
    }

    // Calculate daily steps: current raw sensor steps minus the baseline for the day.
    // Ensure it doesn't go negative.
    final int calculatedDailySteps = (cumulativeStepsFromSensor - _dailyStepBaseline).clamp(0, 1000000);

    // Only update if steps have increased to avoid unnecessary UI updates or saving identical values
    if (calculatedDailySteps > _dailySteps) {
      _dailySteps = calculatedDailySteps;
      // Store the latest raw sensor steps for inference on app restart
      await prefs.setInt('lastRecordedRawSensorSteps', cumulativeStepsFromSensor);

      final oldPoints = (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints); // This was using _storedDailySteps before.
      final newPoints = (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

      if (newPoints > oldPoints) {
        final gainedPoints = newPoints - oldPoints;
        _totalPoints += gainedPoints;
        await prefs.setInt('totalPoints', _totalPoints);
        debugPrint('📈 Gained $gainedPoints points. New daily steps: $_dailySteps, Total points: $_totalPoints');
      }
      // Always save the latest daily steps
      await prefs.setInt('dailySteps', _dailySteps);
      debugPrint('🚶 Current daily steps: $_dailySteps');
    }

    _safeNotifyListeners();
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      if (_isDisposed) return;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
      debugPrint('💾 Syncing daily stats and total points to database...');
      await _databaseService.saveDailyStats(
        date: today,
        steps: _dailySteps, // Use _dailySteps here
        totalPoints: dailyPoints,
        streak: _currentStreak,
      );
      await _databaseService.saveTotalPoints(_totalPoints);
    });
  }

  Future<int> redeemPoints() async {
    if (!canRedeemPoints) return 0;
    try {
      final pointsToRedeem = dailyRedemptionCap;
      if (_totalPoints < pointsToRedeem) {
        debugPrint('Insufficient points to redeem $pointsToRedeem. Current: $_totalPoints');
        return 0;
      }
      pointsRedeemedToday += pointsToRedeem;
      _totalPoints -= pointsToRedeem;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('totalPoints', _totalPoints);
      await _databaseService.saveTotalPoints(_totalPoints);
      _safeNotifyListeners();
      debugPrint('💰 Redeemed $pointsToRedeem points. Remaining: $_totalPoints');
      return pointsToRedeem;
    } catch (e) {
      debugPrint('❌ Redeem failed: $e');
    }
    return 0;
  }

  Future<void> resetSteps() async {
    // This is a manual reset for the UI and app's internal daily count
    _dailySteps = 0;
    _dailyStepBaseline = 0; // Reset baseline so next sensor reading starts from 0 for the daily count
    _rawSensorSteps = 0; // Reset this too to ensure consistency if mock steps are added
    pointsRedeemedToday = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dailySteps', 0);
    await prefs.setInt('dailyStepBaseline', 0);
    await prefs.remove('lastRecordedRawSensorSteps'); // Clear this for a fresh start on manual reset

    _safeNotifyListeners(); // Use safeNotifyListeners
    debugPrint('🔁 Steps manually reset to 0 (and baseline)');
  }

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

  Future<void> addMockSteps(int stepsToAdd) async {
    if (!_isPhysicalDevice) {
      // For mock steps, directly add to _rawSensorSteps to simulate cumulative sensor
      _rawSensorSteps += stepsToAdd;
      _handleStepCount(_rawSensorSteps); // Pass the simulated cumulative steps
    } else {
      debugPrint('🚫 Mock steps can only be added in a non-physical device environment.');
    }
  }

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