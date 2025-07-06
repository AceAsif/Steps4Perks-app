import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class StepTracker with ChangeNotifier {
  int _currentSteps = 0;
  int get currentSteps => _currentSteps;

  int _baseSteps = 0;
  int _totalPoints = 0;
  int get totalPoints => _totalPoints;

  Stream<StepCount>? _stepCountStream;

  static const int stepsPerPoint = 100;
  static const int maxDailySteps = 10000;  // ✅ Max step cap for points
  static const int maxDailyPoints = 100;   // Derived automatically, kept for reference
  static const int giftCardThreshold = 2500;

  StepTracker() {
    _init();
  }

  Future<void> _init() async {
    await _requestPermission();
    await _loadBaseline();
    await _loadPoints();
    _startListening();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.activityRecognition.request();
    if (status.isPermanentlyDenied) await openAppSettings();
  }

  void _startListening() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream?.listen(
      _onStepCount,
      onError: _onStepCountError,
      cancelOnError: true,
    );
  }

  // ✅ Mock step adder for testing:
  void addMockSteps(int stepsToAdd) async {
    _currentSteps += stepsToAdd;

    final prefs = await SharedPreferences.getInstance();
    final storedSteps = prefs.getInt('dailySteps') ?? 0;

    final cappedSteps = _currentSteps.clamp(0, maxDailySteps);
    final oldPoints = (storedSteps.clamp(0, maxDailySteps)) ~/ stepsPerPoint;
    final newPoints = (cappedSteps) ~/ stepsPerPoint;

    if (newPoints > oldPoints) {
      final gained = newPoints - oldPoints;
      _totalPoints += gained;
      prefs.setInt('totalPoints', _totalPoints);
      prefs.setInt('dailySteps', cappedSteps);
    }

    notifyListeners();
  }

  Future<void> _loadBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString('lastResetDate') ?? '';
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (lastDate != today) {
      _baseSteps = -1;
      prefs.setInt('dailySteps', 0);
    } else {
      _baseSteps = prefs.getInt('baseSteps') ?? 0;
    }
  }

  Future<void> _loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    _totalPoints = prefs.getInt('totalPoints') ?? 0;
  }

  int get dailyPoints {
    final cappedSteps = _currentSteps.clamp(0, maxDailySteps);
    return (cappedSteps / stepsPerPoint).floor();
  }

  bool get canRedeemGiftCard => _totalPoints >= giftCardThreshold;

  void redeemGiftCard() async {
    if (_totalPoints >= giftCardThreshold) {
      _totalPoints -= giftCardThreshold;
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt('totalPoints', _totalPoints);
      notifyListeners();
    }
  }

  void _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (_baseSteps == -1) {
      _baseSteps = event.steps;
      prefs.setString('lastResetDate', today);
      prefs.setInt('baseSteps', _baseSteps);
      return;
    }

    _currentSteps = event.steps - _baseSteps;
    if (_currentSteps < 0) _currentSteps = 0;

    final storedSteps = prefs.getInt('dailySteps') ?? 0;
    final cappedSteps = _currentSteps.clamp(0, maxDailySteps);
    final oldPoints = (storedSteps.clamp(0, maxDailySteps)) ~/ stepsPerPoint;
    final newPoints = (cappedSteps) ~/ stepsPerPoint;

    if (newPoints > oldPoints) {
      final gained = newPoints - oldPoints;
      _totalPoints += gained;
      prefs.setInt('totalPoints', _totalPoints);
      prefs.setInt('dailySteps', cappedSteps);
    }

    notifyListeners();
  }

  void _onStepCountError(error) {
    debugPrint("Pedometer error: $error");
  }
}
