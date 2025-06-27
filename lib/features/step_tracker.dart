import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class StepTracker with ChangeNotifier {
  int _steps = 0;
  Stream<StepCount>? _stepCountStream;

  int get steps => _steps;

  StepTracker() {
    _init();
  }

  Future<void> _init() async {
    await _requestPermission();
    _startListening();
  }

  Future<void> _requestPermission() async {
    if (await Permission.activityRecognition.isDenied) {
      await Permission.activityRecognition.request();
    }
  }

  void _startListening() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream?.listen(_onStepCount).onError(_onStepCountError);
  }

  void _onStepCount(StepCount event) {
    _steps = event.steps;
    notifyListeners();
  }

  void _onStepCountError(error) {
    debugPrint('Pedometer error: $error');
  }
}
