import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class StepTracker with ChangeNotifier {
  int _currentSteps = 0;
  int get currentSteps => _currentSteps;

  int _baseSteps = 0;
  Stream<StepCount>? _stepCountStream;

  StepTracker() {
    _init();
  }

  Future<void> _init() async {
    await _requestPermission();
    await _loadBaseline();
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

  Future<void> _loadBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString('lastResetDate') ?? '';
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (lastDate != today) {
      // New day — wait for first step count to set baseline
      _baseSteps = -1;
    } else {
      _baseSteps = prefs.getInt('baseSteps') ?? 0;
    }
  }

  void _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (_baseSteps == -1) {
      // First reading of the day becomes the baseline
      _baseSteps = event.steps;
      prefs.setString('lastResetDate', today);
      prefs.setInt('baseSteps', _baseSteps);
    }

    _currentSteps = event.steps - _baseSteps;
    if (_currentSteps < 0) _currentSteps = 0; // Avoid negative values

    notifyListeners();
  }

  void _onStepCountError(error) {
    debugPrint("Pedometer error: $error");
  }
}
