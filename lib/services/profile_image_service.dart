import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing profile image selection using local assets
/// Images are stored in assets/ folder and selection is saved per user in SharedPreferences
class ProfileImageService {
  static const _defaultIndex = 0;

  // 🟢 Your 3 local image assets
  static final List<String> _avatarPaths = [
    'assets/profile.png',
    'assets/female.png',
    'assets/run.png',
  ];

  // 🟢 Scope the SharedPreferences key to the current user's UID
  // This prevents Asif's profile image from showing for Selena
  static String _getKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'profileImageIndex'; // Fallback for logged-out state
    return 'profileImageIndex_$uid'; // User-specific key
  }

  /// Save the selected image index for the current user
  static Future<void> saveSelectedImageIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_getKey(), index);
  }

  /// Get the selected image index for the current user
  static Future<int> getSelectedImageIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_getKey()) ?? _defaultIndex;
  }

  /// Get the selected image path for the current user
  static Future<String> getSelectedImage() async {
    int index = await getSelectedImageIndex();
    return _avatarPaths[index];
  }

  /// Get all available avatar paths (for UI selection)
  static List<String> getAvailableAvatars() {
    return List.unmodifiable(_avatarPaths);
  }

  /// Clear the profile image for the current user only
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getKey());
  }

  /// Clear all user profile images (for complete sign-out cleanup)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('profileImageIndex_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
