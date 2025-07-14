import 'package:flutter/material.dart'; // For debugPrint
import 'dart:async'; // For Completer

/// A service to simulate rewarded video ads when Google Mobile Ads SDK is not initialized.
/// This is a mock implementation for development/testing without a full AdMob setup.
///
/// --- MODIFIED: This version is effectively "disabled" for testing purposes. ---
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // Keep these flags for consistency, but their values won't matter as much.
  bool _adLoaded = true; // Always true to enable the button for testing
  bool _isAdLoading = false;

  // No actual ad unit ID needed for a disabled mock.
  // final String _adUnitId = 'ca-app-pub-3940256099942544/5224354917';

  /// Simulates loading a rewarded ad.
  /// In this disabled mock, it does nothing and immediately "loads" the ad.
  Future<void> loadRewardedAd() async {
    debugPrint('Mock AdService: (DISABLED) loadRewardedAd called, but doing nothing.');
    _adLoaded = true; // Ensure the ad is always "loaded" so the button is active
    // No delay, no actual loading.
  }

  /// Simulates showing a rewarded ad.
  /// In this disabled mock, it does nothing and immediately returns true.
  Future<bool> showRewardedAd() async {
    debugPrint('Mock AdService: (DISABLED) showRewardedAd called, but doing nothing.');
    // No delay, no actual ad display.
    _adLoaded = true; // Keep it true so the button remains active after a "show"
    return true; // Always simulate success
  }

  /// Checks if a mock ad is currently "loaded" and ready to be shown.
  /// Always returns true in this disabled mock.
  bool get isAdReady {
    debugPrint('Mock AdService: (DISABLED) isAdReady called, returning true.');
    return true; // Always ready to allow button to be active
  }

  /// Simulates disposing of ad resources.
  /// In this disabled mock, it does nothing.
  void dispose() {
    debugPrint('Mock AdService: (DISABLED) Disposing mock ad resources called, but doing nothing.');
    _adLoaded = true; // Keep it true
  }
}
