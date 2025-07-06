//TODO: Future Implementation of this code for Google Fit

/*import 'package:health/health.dart';

class GoogleFitService {
  final HealthFactory _health = HealthFactory(useHealthConnectIfAvailable: true);

  /// Fetches the total steps in the last 24 hours from Google Fit.
  Future<int> fetchSteps() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    // Data types & permissions
    final types = [HealthDataType.STEPS];
    final permissions = [HealthDataAccess.READ];

    // Request permission
    final authorized = await _health.requestAuthorization(types, permissions: permissions);
    if (!authorized) {
      throw Exception('Google Fit authorization failed.');
    }

    // Fetch steps
    final data = await _health.getHealthDataFromTypes(yesterday, now, types);
    final totalSteps = data.fold<int>(
      0,
      (sum, point) => sum + (point.value as int),
    );

    return totalSteps;
  }
}
*/
