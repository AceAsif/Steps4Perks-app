import 'dart:async';
import 'package:flutter/foundation.dart';
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
  static const int stepsPerPoint = 100;
  static const int maxDailyPoints = 100;
  static const int dailyRedemptionCap = 2500;

  int _rawSensorSteps = 0;
  int _dailySteps = 0;
  int _dailyStepBaseline = 0;
  int _totalPoints = 0;
  int _currentStreak = 0;
  bool _isPedometerAvailable = false;
  bool _isPhysicalDevice = true;
  bool _isNewDay = false;
  int pointsRedeemedToday = 0;

  bool _hasClaimedToday = false;
  String? _lastClaimCheckedDate;
  StepStatus _status = StepStatus.idle;

  final _deviceService = DeviceService();
  final _permissionService = PermissionService();
  final _pedometerService = PedometerService();
  final _streakManager = StreakManager();
  final _databaseService = DatabaseService();

  Timer? _syncTimer;
  bool _isDisposed = false;

  StepTracker() {
    _init();
  }

  int get currentSteps => _dailySteps;
  int get totalPoints => _totalPoints;
  int get currentStreak => _currentStreak;
  bool get isPedometerAvailable => _isPedometerAvailable;
  bool get isNewDay => _isNewDay;
  bool get canRedeemPoints => (_totalPoints - pointsRedeemedToday) >= dailyRedemptionCap;
  bool get isPhysicalDevice => _isPhysicalDevice;
  bool get hasClaimedToday => _hasClaimedToday;
  String? get lastClaimCheckedDate => _lastClaimCheckedDate;
  StepStatus get status => _status;
  int get dailyPoints => (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

  void clearNewDayFlag() {
    _isNewDay = false;
    _safeNotifyListeners();
  }

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
    if (_lastClaimCheckedDate == date && _hasClaimedToday) return;

    final prefs = await SharedPreferences.getInstance();
    final lastChecked = prefs.getString('lastClaimCheckedDate') ?? '';

    if (lastChecked != date) {
      _hasClaimedToday = false;
      _lastClaimCheckedDate = date;
      await prefs.setString('lastClaimCheckedDate', date);
      _safeNotifyListeners();
    }

    try {
      final snapshot = await databaseService.getDailyStatsOnce(date);
      if (snapshot != null && snapshot['redeemed'] == true) {
        _hasClaimedToday = true;
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('❌ checkIfClaimedToday: $e');
    }
  }

  Future<bool> claimDailyPoints(String date) async {
    try {
      final success = await _databaseService.updateDailyStatsRedeemedStatus(
        date: date,
        redeemed: true,
      );

      if (success) {
        _hasClaimedToday = true;
        _safeNotifyListeners();
        debugPrint('✅ Daily points marked as claimed for $date.');
      }
      return success;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in claimDailyPoints: $e');
      debugPrint('Stack Trace: $stackTrace');
      return false;
    }
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
        debugPrint('⚠️ Pedometer unavailable or permission denied/not a physical device.');
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

    if (lastDate != today) {
      _isNewDay = true;
      _dailySteps = 0;
      _dailyStepBaseline = 0;
      await prefs.setInt('dailySteps', 0);
      await prefs.setInt('dailyStepBaseline', 0);
      await prefs.remove('lastRecordedRawSensorSteps');
      _currentStreak = await _streakManager.evaluate(today, prefs, 0);
      await prefs.setString('lastResetDate', today);
      await prefs.setInt('currentStreak', _currentStreak);
    } else {
      _dailySteps = prefs.getInt('dailySteps') ?? 0;
      _dailyStepBaseline = prefs.getInt('dailyStepBaseline') ?? 0;
      _currentStreak = prefs.getInt('currentStreak') ?? 0;
    }

    await checkIfClaimedToday(today, _databaseService);
    _safeNotifyListeners();
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

    if (today != lastDate) {
      _isNewDay = true;
      _dailySteps = 0;
      _dailyStepBaseline = cumulativeStepsFromSensor;
      await prefs.setInt('dailySteps', 0);
      await prefs.setInt('dailyStepBaseline', _dailyStepBaseline);
      await prefs.setString('lastResetDate', today);
      _currentStreak = await _streakManager.evaluate(today, prefs, 0);
      await prefs.setInt('currentStreak', _currentStreak);
      await checkIfClaimedToday(today, _databaseService);
    } else {
      if (_dailyStepBaseline == 0 && cumulativeStepsFromSensor > 0) {
        final lastSavedDailySteps = prefs.getInt('dailySteps') ?? 0;
        final lastRecordedRawSensorSteps = prefs.getInt('lastRecordedRawSensorSteps') ?? 0;
        _dailyStepBaseline = (lastRecordedRawSensorSteps > 0)
            ? lastRecordedRawSensorSteps - lastSavedDailySteps
            : cumulativeStepsFromSensor - lastSavedDailySteps;
        await prefs.setInt('dailyStepBaseline', _dailyStepBaseline);
      }
    }

    final int calculatedDailySteps = (cumulativeStepsFromSensor - _dailyStepBaseline).clamp(0, 1000000);

    if (calculatedDailySteps > _dailySteps) {
      _dailySteps = calculatedDailySteps;
      await prefs.setInt('lastRecordedRawSensorSteps', cumulativeStepsFromSensor);
      final oldPoints = dailyPoints;
      final newPoints = (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);
      if (newPoints > oldPoints) {
        _totalPoints += (newPoints - oldPoints);
        await prefs.setInt('totalPoints', _totalPoints);
      }
      await prefs.setInt('dailySteps', _dailySteps);
    }

    _safeNotifyListeners();
  }

  Future<Map<String, dynamic>?> getDailyStatsForUI(String date) async {
    try {
      // This method already uses databaseService.getDailyStatsOnce
      // and performs the claim check, making it suitable for UI calls.
      // However, if you only need the raw data, a simpler method is better.
      // Let's create a dedicated one for getting daily stats for the UI.
      return await _databaseService.getDailyStatsOnce(date);
    } catch (e) {
      debugPrint('❌ StepTracker.getDailyStatsForUI error: $e');
      return null;
    }
  }


  void _startSyncTimer() {
    int lastSyncedSteps = -1;
    int lastSyncedPoints = -1;

    _syncTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      if (_isDisposed) return;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
      if (_dailySteps != lastSyncedSteps || _totalPoints != lastSyncedPoints) {
        _status = StepStatus.syncing;
        _safeNotifyListeners();
        try {
          await _databaseService.saveStatsAndPoints(
            date: today,
            steps: _dailySteps,
            dailyPointsEarned: dailyPoints, // This is your daily calculated points
            streak: _currentStreak,
            totalPoints: _totalPoints, // This is your running total points
          );
          // REMOVE THE LINE BELOW:
          // await _databaseService.saveTotalPoints(_totalPoints); // <-- THIS LINE IS THE PROBLEM

          lastSyncedSteps = _dailySteps;
          lastSyncedPoints = _totalPoints;
          _status = StepStatus.synced;
          debugPrint('✅ Data synced: Daily Steps: $_dailySteps, Total Points: $_totalPoints');
        } catch (e) {
          _status = StepStatus.failed;
          debugPrint('❌ Sync failed: $e');
        } finally {
          _safeNotifyListeners();
        }
      } else {
        debugPrint('✅ No changes to sync.');
      }
    });
  }

  Future<int> redeemPoints() async {
    if (!canRedeemPoints) return 0;
    try {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
      final redeemedAmount = dailyRedemptionCap;

      pointsRedeemedToday += redeemedAmount;
      _totalPoints -= redeemedAmount;

      final success = await _databaseService.redeemDailyPoints(
        date: date,
        pointsToRedeem: redeemedAmount,
        currentTotalPoints: _totalPoints,
      );

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('totalPoints', _totalPoints);
        _hasClaimedToday = true;
        _safeNotifyListeners();
        return redeemedAmount;
      } else {
        _totalPoints += redeemedAmount;
        pointsRedeemedToday -= redeemedAmount;
        _safeNotifyListeners();
        return 0;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Redeem failed: $e');
      debugPrint('Stack Trace: $stackTrace');
      return 0;
    }
  }

  Future<void> resetSteps() async {
    _dailySteps = 0;
    _dailyStepBaseline = 0;
    _rawSensorSteps = 0;
    pointsRedeemedToday = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dailySteps', 0);
    await prefs.setInt('dailyStepBaseline', 0);
    await prefs.remove('lastRecordedRawSensorSteps');
    _safeNotifyListeners();
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
    // Temporarily bypass _isPhysicalDevice check for emulator testing as per user's request context
    // REMOVE THE `if` BLOCK AND `else` BLOCK BELOW FOR FINAL PRODUCTION
    // OR, better, configure your build flavors for debug/release to enable/disable this properly.
    // For now, based on the context that you want it to work on emulator:
    // We're assuming the emulator shows "Emulator Mode Active" but DeviceService thinks it's physical.
    // For immediate fix, we'll make it always add steps.
    // In a real app, you'd properly detect debug build/emulator.

    // Direct addition for mock steps:
    _dailySteps += stepsToAdd; // Directly increment the daily step count
    debugPrint('📈 Added $stepsToAdd mock steps. New _dailySteps: $_dailySteps');

    // Also update total points based on new daily steps, if applicable
    final oldPoints = dailyPoints; // Points before this addition
    final newPoints = (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);
    if (newPoints > oldPoints) {
      _totalPoints += (newPoints - oldPoints);
      await SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('totalPoints', _totalPoints);
      });
      debugPrint('💰 Gained ${newPoints - oldPoints} points from mock steps. Total points: $_totalPoints');
    }

    // Save the updated daily steps to shared preferences to persist across app restarts
    await SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('dailySteps', _dailySteps);
    });

    // Since mock steps are directly updating _dailySteps, we notify listeners immediately.
    _safeNotifyListeners();

    // Also trigger a sync to database if it's necessary for mock steps to be persisted immediately
    // You can decide if you want mock steps to always trigger a sync, or just rely on the timer.
    // For immediate visual feedback on database, you could call _startSyncTimer's logic or a specific sync method.
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
    await _databaseService.saveStatsAndPoints(
      date: today,
      steps: _dailySteps,
      dailyPointsEarned: dailyPoints,
      streak: _currentStreak,
      totalPoints: _totalPoints,
    );
    debugPrint('✅ Mock steps synced to database.');
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
