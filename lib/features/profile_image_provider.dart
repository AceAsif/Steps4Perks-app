import 'package:flutter/material.dart';
import 'package:myapp/services/profile_image_service.dart';
import 'package:myapp/services/database_service.dart';

class ProfileImageProvider with ChangeNotifier {
  int _selectedImageIndex = 0;
  bool _isLoading = false;

  int get selectedImageIndex => _selectedImageIndex;
  bool get isLoading => _isLoading;

  /// Load profile image for a specific user
  /// Priority: Firestore > SharedPreferences > Default (0)
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
        await ProfileImageService.saveSelectedImageIndex(firestoreIndex);
        debugPrint('📸 ✅ Loaded from Firestore: $firestoreIndex (cached locally)');
      } else {
        // 🟢 STEP 2: Fallback to SharedPreferences (local cache)
        _selectedImageIndex = await ProfileImageService.getSelectedImageIndex();
        debugPrint('📸 ⚠️ Loaded from SharedPreferences (local): $_selectedImageIndex');

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
  /// Saves to BOTH SharedPreferences (local) AND Firestore (cloud)
  Future<void> updateImageIndex(int newIndex) async {
    debugPrint('📸 Updating profile image index to: $newIndex');

    _selectedImageIndex = newIndex;
    notifyListeners(); // Update UI immediately

    try {
      // 🟢 STEP 1: Save to SharedPreferences (local, fast)
      await ProfileImageService.saveSelectedImageIndex(newIndex);
      debugPrint('📸 ✅ Saved to SharedPreferences: $newIndex');

      // 🟢 STEP 2: Save to Firestore (cloud, syncs across devices)
      await DatabaseService().saveProfileImageIndex(newIndex);
      debugPrint('📸 ✅ Saved to Firestore: $newIndex');

      debugPrint('✅ Profile image updated successfully to index $newIndex');
    } catch (e, stack) {
      debugPrint('❌ Error updating profile image: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  /// Clear profile image state (for logout)
  void clear() {
    debugPrint('🧹 ProfileImageProvider: State cleared');
    _selectedImageIndex = 0;
    _isLoading = false;
    notifyListeners();
  }
}
