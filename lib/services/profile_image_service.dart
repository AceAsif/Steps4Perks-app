import 'package:shared_preferences/shared_preferences.dart';

class ProfileImageService {
  static const _key = 'profileImageIndex';
  static const _defaultIndex = 0;

  static final List<String> _avatarPaths = [
    'assets/profile.png',
    'assets/female.png',
    'assets/run.png',
  ];

  static Future<void> saveSelectedImageIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, index);
  }

  static Future<int> getSelectedImageIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? _defaultIndex;
  }

  static Future<String> getSelectedImage() async {
    int index = await getSelectedImageIndex();
    return _avatarPaths[index];
  }
}
