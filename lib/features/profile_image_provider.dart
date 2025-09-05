import 'package:flutter/material.dart';
import 'package:myapp/services/profile_image_service.dart';

class ProfileImageProvider extends ChangeNotifier {
  int _selectedImageIndex = 0;

  int get selectedImageIndex => _selectedImageIndex;

  ProfileImageProvider() {
    _loadImageIndex();
  }

  Future<void> _loadImageIndex() async {
    _selectedImageIndex = await ProfileImageService.getSelectedImageIndex();
    notifyListeners();
  }

  Future<void> updateImageIndex(int newIndex) async {
    _selectedImageIndex = newIndex;
    await ProfileImageService.saveSelectedImageIndex(newIndex);
    notifyListeners();
  }
}
