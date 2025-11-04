import 'package:flutter/material.dart';
import 'package:myapp/services/profile_image_service.dart';
import 'package:myapp/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileImageProvider with ChangeNotifier {
  int _selectedImageIndex = 0;
  bool _isLoading = false;

  int get selectedImageIndex => _selectedImageIndex;
  bool get isLoading => _isLoading;

  // 🟢 NEW: Generate user-specific SharedPreferences keys
  String _getPrefsKey(String key) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('⚠️ _getPrefsKey: No user logged in, using non-namespaced key');
      return key;
    }
    return '${userId}_$key'; // Prefix all keys with user ID
  }

  /// Load profile image for a specific user
  /// Priority: Firestore > SharedPreferences (user-namespaced) > Default (0)
  Future<void> loadForUser(String uid) async {
    debugPrint('👤 ProfileImageProvider: Loading profile image for user $uid');
    _isLoading = true;
    notifyListeners();

    try {
      // 🟢 STEP 1: Try loading from Firestore (cloud)
      final firestoreIndex = await DatabaseService().loadProfileImageIndex();

      if (firestoreIndex != null) {
        // Found in Firestore - use it and cache locally
        _selectedImageIndex = firestoreIndex;

        // 🟢 FIXED: Save to user-namespaced SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_getPrefsKey('profileImageIndex'), firestoreIndex);

        debugPrint('📸 ✅ Loaded from Firestore: $firestoreIndex (cached locally with user namespace)');
      } else {
        // 🟢 STEP 2: Fallback to user-namespaced SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        _selectedImageIndex = prefs.getInt(_getPrefsKey('profileImageIndex')) ?? 0;

        debugPrint('📸 ⚠️ Loaded from SharedPreferences (user-namespaced): $_selectedImageIndex');

        // If we have a local preference but not in Firestore, save it to Firestore
        if (_selectedImageIndex != 0) {
          await DatabaseService().saveProfileImageIndex(_selectedImageIndex);
          debugPrint('📸 💾 Synced local preference to Firestore: $_selectedImageIndex');
        }
      }
    } catch (e, stack) {
      debugPrint('❌ Error loading profile image: $e');
      debugPrint('Stack trace: $stack');
      _selectedImageIndex = 0; // Default fallback
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update profile image index
  /// Saves to BOTH SharedPreferences (local, user-namespaced) AND Firestore (cloud, syncs across devices)
  Future<void> updateImageIndex(int newIndex) async {
    debugPrint('📸 Updating profile image index to: $newIndex');

    _selectedImageIndex = newIndex;
    notifyListeners(); // Update UI immediately

    try {
      // 🟢 STEP 1: Save to user-namespaced SharedPreferences (local, fast)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_getPrefsKey('profileImageIndex'), newIndex);
      debugPrint('📸 ✅ Saved to SharedPreferences (user-namespaced): $newIndex');

      // 🟢 STEP 2: Save to Firestore (cloud, syncs across devices)
      await DatabaseService().saveProfileImageIndex(newIndex);
      debugPrint('📸 ✅ Saved to Firestore: $newIndex');

      debugPrint('✅ Profile image updated successfully to index $newIndex');
    } catch (e, stack) {
      debugPrint('❌ Error updating profile image: $e');
      debugPrint('Stack trace: $stack');
      // Note: UI already updated optimistically, error is logged but not reverted
    }
  }

  /// Clear profile image state (for logout)
  void clear() {
    debugPrint('🧹 ProfileImageProvider: State cleared');
    _selectedImageIndex = 0;
    _isLoading = false;
    notifyListeners();
  }

  /// 🟢 NEW: Clear user-specific SharedPreferences when switching users
  /// This ensures old user's data doesn't bleed into new user's session
  Future<void> clearUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userIdKey = _getPrefsKey('profileImageIndex');

      if (prefs.containsKey(userIdKey)) {
        await prefs.remove(userIdKey);
        debugPrint('✅ Cleared user-specific profile image preference');
      }
    } catch (e) {
      debugPrint('⚠️ Error clearing user preferences: $e');
    }
  }
}
