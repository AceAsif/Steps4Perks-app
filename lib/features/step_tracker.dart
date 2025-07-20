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

  int _currentSteps = 0;
  int _storedDailySteps = 0;
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

  DatabaseService get databaseService => _databaseService; // ✅ public getter added

  Timer? _syncTimer;
  bool _isDisposed = false;

  StepTracker() {
    _init();
  }

  int get currentSteps => _currentSteps;
  int get totalPoints => _totalPoints;
  int get currentStreak => _currentStreak;
  bool get isPedometerAvailable => _isPedometerAvailable;
  bool get isNewDay => _isNewDay;
  bool get canRedeemPoints => (_totalPoints - pointsRedeemedToday) >= dailyRedemptionCap;
  bool get isPhysicalDevice => _isPhysicalDevice;
  int get dailyPoints => (_currentSteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

  void clearNewDayFlag() {
    _isNewDay = false;
    _safeNotifyListeners();
  }

  void setCurrentSteps(int steps) {
    _currentSteps = steps;
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

    if (lastChecked != date) {
      _hasClaimedToday = false;
      _lastClaimCheckedDate = date;
      await prefs.setString('lastClaimCheckedDate', date);
      notifyListeners();
    }

    try {
      final snapshot = await databaseService.getDailyStatsStream(date).first;
      if (snapshot != null && snapshot['redeemed'] == true) {
        _hasClaimedToday = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ checkIfClaimedToday: $e');
    }
  }

  Future<bool> claimDailyPoints(String date) async {
    final success = await _databaseService.redeemDailyPoints(date: date);
    if (success) {
      _hasClaimedToday = true;
      notifyListeners();
    }
    return success;
  }

  Future<void> _init() async {
    try {
      _isPhysicalDevice = await _deviceService.checkIfPhysicalDevice();
      _isPedometerAvailable = await _permissionService.requestActivityPermission();
      await _permissionService.requestBatteryOptimizationException();

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
        debugPrint('⚠️ Pedometer unavailable or permission denied');
        _handleStepCount(_currentSteps);
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
      await prefs.setInt('dailySteps', 0);
      await prefs.setString('lastResetDate', today);
      _storedDailySteps = 0;
      _currentSteps = 0;

      _currentStreak = await _streakManager.evaluate(today, prefs, 0);
    } else {
      _storedDailySteps = prefs.getInt('dailySteps') ?? 0;
      _currentSteps = _storedDailySteps;
      _currentStreak = prefs.getInt('currentStreak') ?? 0;
    }

    await checkIfClaimedToday(today, _databaseService);
  }

  Future<void> _loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    _totalPoints = prefs.getInt('totalPoints') ?? 0;
  }

  void _handleStepCount(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
    final lastDate = prefs.getString('lastResetDate') ?? '';

    debugPrint('📅 Today: $today, Last Reset: $lastDate, Incoming Steps: $steps');

    // Save the latest incoming step count FIRST
    _currentSteps = steps;

    // If it’s a new day, reset the daily values
    if (today != lastDate) {
      debugPrint('🔄 Detected new day. Resetting daily stats.');

      _isNewDay = true;
      _storedDailySteps = 0;

      _currentStreak = await _streakManager.evaluate(today, prefs, 0);
      await prefs.setString('lastResetDate', today);
      await prefs.setInt('dailySteps', 0);
      await prefs.setInt('currentStreak', _currentStreak);
      await checkIfClaimedToday(today, _databaseService);
    } else {
      // Load previous stored steps for comparison
      _storedDailySteps = prefs.getInt('dailySteps') ?? 0;
      _currentStreak = prefs.getInt('currentStreak') ?? 0;
    }

    final oldPoints = (_storedDailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);
    final newPoints = (_currentSteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

    if (newPoints > oldPoints) {
      final gainedPoints = newPoints - oldPoints;
      _totalPoints += gainedPoints;
      _storedDailySteps = _currentSteps;

      await prefs.setInt('dailySteps', _currentSteps);
      await prefs.setInt('totalPoints', _totalPoints);
    }

    _safeNotifyListeners();
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      if (_isDisposed) return;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
      await _databaseService.saveDailyStats(
        date: today,
        steps: _currentSteps,
        totalPoints: dailyPoints,
        streak: _currentStreak,
      );
      await _databaseService.saveTotalPoints(_totalPoints);
    });
  }

  Future<int> redeemPoints() async {
    if (!canRedeemPoints) return 0;
    try {
      pointsRedeemedToday += dailyRedemptionCap;
      _totalPoints -= dailyRedemptionCap;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('totalPoints', _totalPoints);
      await _databaseService.saveTotalPoints(_totalPoints);
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('❌ Redeem failed: $e');
    }
    return dailyRedemptionCap;
  }

  Future<void> resetSteps() async {
    _currentSteps = 0;
    _storedDailySteps = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dailySteps', 0);

    notifyListeners();
    debugPrint('🔁 Steps manually reset to 0');
  }

  void _handleStepError(dynamic error) {
    debugPrint('Step count error: $error');
    _isPedometerAvailable = false;
    _safeNotifyListeners();
  }

  void _handlePedStatus(String status) {
    debugPrint('🚶 Pedestrian status: $status');
    // You could update a variable here and notify listeners to show it in the UI
  }

  void _handlePedStatusError(dynamic error) {
    debugPrint('Pedestrian status error: $error');
    _isPedometerAvailable = false;
    _safeNotifyListeners();
  }

  Future<void> addMockSteps(int stepsToAdd) async {
    if (!_isPhysicalDevice) {
      _currentSteps += stepsToAdd;
      _handleStepCount(_currentSteps);
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
