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

  final DeviceService _deviceService = DeviceService();
  final PermissionService _permissionService = PermissionService();
  final PedometerService _pedometerService = PedometerService();
  final StreakManager _streakManager = StreakManager();
  final DatabaseService _databaseService = DatabaseService();

  Timer? _syncTimer;

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
    notifyListeners();
  }

  Future<void> _init() async {
    _isPhysicalDevice = await _deviceService.checkIfPhysicalDevice();
    _isPedometerAvailable = await _permissionService.requestActivityPermission();

    await _loadBaseline();
    await _loadPoints();

    if (_isPhysicalDevice && _isPedometerAvailable) {
      _pedometerService.startListening(
        onStepCount: _handleStepCount,
        onStepError: _handleStepError,
        onPedestrianStatusChanged: _handlePedStatus,
        onPedestrianStatusError: _handlePedStatusError,
      );
    }

    _startSyncTimer();
    notifyListeners();
  }

  Future<void> _loadBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDate = prefs.getString('lastResetDate') ?? '';

    if (lastDate != today) {
      _isNewDay = true;
      await prefs.setInt('dailySteps', 0);
      await prefs.setString('lastResetDate', today);
      _storedDailySteps = 0;
      _currentSteps = 0;

      _currentStreak = await _streakManager.evaluate(today, prefs, _storedDailySteps);
    } else {
      _storedDailySteps = prefs.getInt('dailySteps') ?? 0;
      _currentSteps = _storedDailySteps;
      _currentStreak = prefs.getInt('currentStreak') ?? 0;
    }
  }

  Future<void> _loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    _totalPoints = prefs.getInt('totalPoints') ?? 0;
  }

  void _handleStepCount(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    _currentSteps = steps;

    final oldPoints = (_storedDailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);
    final newPoints = (_currentSteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

    if (newPoints > oldPoints) {
      final gainedPoints = newPoints - oldPoints;
      _totalPoints += gainedPoints;
      _storedDailySteps = _currentSteps;

      await prefs.setInt('dailySteps', _currentSteps);
      await prefs.setInt('totalPoints', _totalPoints);
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _currentStreak = await _streakManager.evaluate(today, prefs, _storedDailySteps);

    notifyListeners();
  }

  //This is the code that writes to the database every 5 mins.
  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      try {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

        debugPrint('🕒 Syncing Firestore at ${DateTime.now()}');
        debugPrint('👣 Steps: $_currentSteps | 🪙 Points: $dailyPoints');

        await _databaseService.saveDailyStats(
          date: today,
          steps: _currentSteps,
          totalPoints: dailyPoints,
          streak: _currentStreak, // ✅ Add this line
        );

        await _databaseService.saveTotalPoints(_totalPoints);
      } catch (e) {
        debugPrint('❌ Firestore sync failed: $e');
      }
    });
  }

  Future<int> redeemPoints() async {
    if (!canRedeemPoints) return 0;

    pointsRedeemedToday += dailyRedemptionCap;
    _totalPoints -= dailyRedemptionCap;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('totalPoints', _totalPoints);
    await _databaseService.saveTotalPoints(_totalPoints);

    notifyListeners();
    return dailyRedemptionCap;
  }

  void _handleStepError(dynamic error) {
    debugPrint('Step count error: $error');
    _isPedometerAvailable = false;
    notifyListeners();
  }

  void _handlePedStatus(String status) {
    debugPrint('Pedestrian status: $status');
  }

  void _handlePedStatusError(dynamic error) {
    debugPrint('Pedestrian status error: $error');
    _isPedometerAvailable = false;
    notifyListeners();
  }

  Future<void> addMockSteps(int stepsToAdd) async {
    if (!_isPhysicalDevice) {
      _currentSteps += stepsToAdd;
      _handleStepCount(_currentSteps);
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
