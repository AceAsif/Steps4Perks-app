import 'package:pedometer/pedometer.dart';

class PedometerService {
  void startListening({
    required Function(int) onStepCount,
    required Function(dynamic) onStepError,
    required Function(String) onPedestrianStatusChanged,
    required Function(dynamic) onPedestrianStatusError,
  }) {
    Pedometer.stepCountStream.listen(
      (event) => onStepCount(event.steps),
      onError: onStepError,
    );

    Pedometer.pedestrianStatusStream.listen(
      (event) => onPedestrianStatusChanged(event.status),
      onError: onPedestrianStatusError,
    );
  }
}
