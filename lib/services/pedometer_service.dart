import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';

class PedometerService {
  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;

  bool get isListening => _stepCountSubscription != null;

  /// Starts listening to the pedometer streams.
  ///
  /// 🟢 FIX: Previously subscriptions were never stored or cancelled, so every
  /// logout/login (or repeated loadForUser call) stacked another listener —
  /// causing duplicate step callbacks and memory leaks. Now we cancel any
  /// existing subscriptions before subscribing again.
  void startListening({
    required Function(int) onStepCount,
    required Function(dynamic) onStepError,
    required Function(String) onPedestrianStatusChanged,
    required Function(dynamic) onPedestrianStatusError,
  }) {
    stopListening();

    _stepCountSubscription = Pedometer.stepCountStream.listen(
      (event) => onStepCount(event.steps),
      onError: onStepError,
      cancelOnError: false,
    );

    _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
      (event) => onPedestrianStatusChanged(event.status),
      onError: onPedestrianStatusError,
      cancelOnError: false,
    );

    debugPrint('👟 PedometerService: Listening started');
  }

  /// Cancels the pedometer stream subscriptions.
  void stopListening() {
    _stepCountSubscription?.cancel();
    _stepCountSubscription = null;
    _pedestrianStatusSubscription?.cancel();
    _pedestrianStatusSubscription = null;
  }
}
