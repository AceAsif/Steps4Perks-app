import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestActivityPermission() async {
    final status = await Permission.activityRecognition.request();
    return status == PermissionStatus.granted;
  }

  Future<void> requestBatteryOptimizationException() async {
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
}
