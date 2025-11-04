import 'package:flutter/material.dart';
import 'package:myapp/services/profile_image_service.dart';

/// Provider for managing profile image state in the app
/// Uses ProfileImageService to persist data in SharedPreferences
class ProfileImageProvider extends ChangeNotifier {
  int _selectedImageIndex = 0;
  bool _isLoading = false;

  int get selectedImageIndex => _selectedImageIndex;
  bool get isLoading => _isLoading;

  // Get the currently selected image path
  String get selectedImagePath {
    final avatars = ProfileImageService.getAvailableAvatars();
    return avatars[_selectedImageIndex];
  }

  // Get all available avatar paths for UI
  List<String> get availableAvatars => ProfileImageService.getAvailableAvatars();

  ProfileImageProvider() {
    _loadImageIndex();
  }

  Future<void> _loadImageIndex() async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedImageIndex = await ProfileImageService.getSelectedImageIndex();
    } catch (e) {
      debugPrint('❌ Error loading image index in constructor: $e');
      _selectedImageIndex = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update the selected profile image
  Future<void> updateImageIndex(int newIndex) async {
    _selectedImageIndex = newIndex;
    await ProfileImageService.saveSelectedImageIndex(newIndex);
    notifyListeners();
  }

  /// 🟢 Clear state when user logs out
  void clear() {
    _selectedImageIndex = 0;
    _isLoading = false;
    debugPrint('🧹 ProfileImageProvider: State cleared');
    notifyListeners();
  }

  /// 🟢 Load profile image for a specific user
  Future<void> loadForUser(String uid) async {
    debugPrint('👤 ProfileImageProvider: Loading profile image for user $uid');
    _isLoading = true;
    notifyListeners();

    try {
      _selectedImageIndex = await ProfileImageService.getSelectedImageIndex();
      debugPrint('📸 Loaded profile image index for user $uid: $_selectedImageIndex');
    } catch (e) {
      debugPrint('❌ Error loading profile image: $e');
      _selectedImageIndex = 0; // Fallback to default
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
