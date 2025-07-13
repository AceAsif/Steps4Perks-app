import 'package:flutter/material.dart'; // For debugPrint
import 'dart:async'; // For Completer

/// A service to simulate rewarded video ads when Google Mobile Ads SDK is not initialized.
/// This is a mock implementation for development/testing without a full AdMob setup.
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _adLoaded = false; // Simulate whether an ad is "loaded"

  /// Simulates loading a rewarded ad.
  /// In a real implementation, this would load an ad from Google Mobile Ads.
  Future<void> loadRewardedAd() async {
    if (_adLoaded) {
      debugPrint('Mock AdService: Ad is already "loaded".');
      return;
    }

    debugPrint('Mock AdService: Simulating ad loading...');
    // Simulate a network delay for loading the ad
    await Future.delayed(const Duration(seconds: 2));

    _adLoaded = true;
    debugPrint('Mock AdService: Rewarded ad "loaded".');
  }

  /// Simulates showing a rewarded ad.
  /// In a real implementation, this would display the ad.
  /// Returns true after a delay, simulating a successful ad watch.
  Future<bool> showRewardedAd() async {
    if (!_adLoaded) {
      debugPrint('Mock AdService: No ad "loaded". Attempting to "load" first...');
      await loadRewardedAd(); // Try to "load" again
      if (!_adLoaded) {
        debugPrint('Mock AdService: Still no ad "loaded". Cannot "show".');
        return false; // Simulate no ad available
      }
    }

    debugPrint('Mock AdService: Simulating ad display...');
    // Simulate the ad playing duration
    await Future.delayed(const Duration(seconds: 3));

    _adLoaded = false; // Simulate ad being consumed after showing
    debugPrint('Mock AdService: Ad "shown" successfully. User "earned reward".');

    // Automatically "load" the next ad after showing one
    loadRewardedAd();

    return true; // Simulate user successfully watching the ad and earning reward
  }

  /// Checks if a mock ad is currently "loaded" and ready to be shown.
  bool get isAdReady => _adLoaded;

  /// Simulates disposing of ad resources.
  void dispose() {
    debugPrint('Mock AdService: Disposing mock ad resources.');
    _adLoaded = false;
  }
}
