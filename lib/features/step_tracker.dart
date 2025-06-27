import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class StepTracker with ChangeNotifier {
  int _currentSteps = 0;
  int get currentSteps => _currentSteps;

  Stream<StepCount>? _stepCountStream;

  StepTracker() {
    _init();
  }

  Future<void> _init() async {
    await _requestPermission();
    _startListening();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.activityRecognition.request();

    if (status.isDenied) {
      debugPrint("Permission denied temporarily.");
    } else if (status.isPermanentlyDenied) {
      debugPrint("Permission permanently denied.");
      // This will open the app's settings page so the user can enable permission manually
      await openAppSettings();
    }
  }

  void _startListening() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream?.listen(
      _onStepCount,
      onError: _onStepCountError,
      onDone: () => debugPrint("Pedometer stream closed"),
      cancelOnError: true,
    );
  }

  void _onStepCount(StepCount event) {
    _currentSteps = event.steps;
    notifyListeners();
  }

  void _onStepCountError(error) {
    debugPrint("Pedometer error: $error");
  }
}
