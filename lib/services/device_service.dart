import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  Future<bool> checkIfPhysicalDevice() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        return info.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        return info.isPhysicalDevice;
      }
      return true;
    } catch (e) {
      return true;
    }
  }
}
