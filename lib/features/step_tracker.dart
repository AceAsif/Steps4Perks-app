import 'package:flutter/material.dart'; // Added for debugPrint and TargetPlatform
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart'; // Provides device information (e.g., if it's a physical device vs. emulator)
import 'package:flutter/foundation.dart'; // Contains defaultTargetPlatform for platform checks
import 'dart:io'; // For Platform.isAndroid/isIOS

/// Manages step tracking, point accumulation, and daily resets for the Steps4Perks app.
///
/// This class extends [ChangeNotifier] to allow its state to be observed by widgets.
/// When its internal state changes (e.g., current steps, total points), it calls
/// [notifyListeners()] to rebuild dependent UI components.
class StepTracker with ChangeNotifier {
  /// Constants
  static const int stepsPerPoint = 100;
  static const int maxDailySteps = 10000;
  static const int maxDailyPoints = 100; // Max points per day (10000 steps / 100 steps/point)
  static const int giftCardThreshold = 2500; // Points needed to redeem a gift card

  /// State
  int _currentSteps = 0;
  int _baseSteps = 0;

  // Accumulates the total points earned across multiple days.
  int _totalPoints = 0;
  int _storedDailySteps = 0; // Stores the last saved daily steps from SharedPreferences
  bool _isNewDay = false; // Flag to indicate if a new day has started

  Stream<StepCount>? _stepCountStream;
  Stream<PedestrianStatus>? _pedestrianStatusStream; // Stream for pedestrian status

  // Flag to indicate if the pedometer sensor is actually available and working on the device.
  bool _isPedometerAvailable = false;

  /// Public Getters
  int get currentSteps => _currentSteps;
  int get totalPoints => _totalPoints;
  bool get isNewDay => _isNewDay;
  bool get isPedometerAvailable => _isPedometerAvailable; // Getter for pedometer availability

  /// Computed daily points (max 100)
  int get dailyPoints {
    final cappedSteps = _currentSteps.clamp(0, maxDailySteps);
    return (cappedSteps / stepsPerPoint).floor().clamp(0, maxDailyPoints);
  }

  /// Computed live total points (includes today's yet-unsaved new points)
  /// This getter calculates total points including any points earned in the
  /// current session that haven't been persisted to _totalPoints yet.
  int get computedTotalPoints {
    // Calculate points based on current steps, capped at maxDailySteps
    final currentDailyPoints = (_currentSteps.clamp(0, maxDailySteps) ~/ stepsPerPoint).clamp(0, maxDailyPoints);
    // Calculate points from previously stored daily steps
    final storedDailyPoints = (_storedDailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

    // Points gained in the current session that are not yet in _totalPoints
    final newPointsToday = currentDailyPoints - storedDailyPoints;

    // Add new points (if positive) to the accumulated total points
    return _totalPoints + (newPointsToday > 0 ? newPointsToday : 0);
  }

  /// Check if user can redeem a gift card
  bool get canRedeemGiftCard => _totalPoints >= giftCardThreshold;

  /// Constructor
  StepTracker() {
    _init();
  }

  /// Initialization
  Future<void> _init() async {
    await _requestPermission(); // Request activity recognition permission
    await _loadBaseline(); // Load last reset date and base steps
    await _loadPoints(); // Load accumulated points
    await _startListening(); // Start pedometer listening conditionally
  }

  /// Permissions
  /// Requests the 'activityRecognition' permission.
  /// Updates [_isPedometerAvailable] based on permission status.
  Future<void> _requestPermission() async {
    final status = await Permission.activityRecognition.request();
    if (status.isPermanentlyDenied) {
      debugPrint('Activity Recognition permission permanently denied. Guiding user to settings.');
      await openAppSettings(); // Open app settings for user to manually enable permission
    }
    // Set initial availability flag based on permission status
    _isPedometerAvailable = status.isGranted;
    if (!status.isGranted) {
      debugPrint('Activity Recognition permission not granted.');
    }
    notifyListeners(); // Notify UI about permission status change
  }

  /// Load base steps and daily state from SharedPreferences.
  /// Checks if a new day has started and resets daily steps if so.
  Future<void> _loadBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDate = prefs.getString('lastResetDate') ?? '';

    if (lastDate != today) {
      // It's a new day!
      _isNewDay = true;
      _baseSteps = -1; // Flag to indicate that _baseSteps needs to be set from the first step event
      _currentSteps = 0; // Reset current steps displayed for the new day
      _storedDailySteps = 0; // Reset stored daily steps
      await prefs.setInt('dailySteps', 0); // Reset daily steps in storage
      await prefs.setString('lastResetDate', today); // Update last reset date
    } else {
      // Same day as last recorded activity
      _isNewDay = false;
      _baseSteps = prefs.getInt('baseSteps') ?? 0; // Load previous base steps
      _storedDailySteps = prefs.getInt('dailySteps') ?? 0; // Load previous daily steps
      _currentSteps = _storedDailySteps; // Set current steps from stored for display
    }
    notifyListeners(); // Notify UI after loading baseline
  }

  /// Load persisted total points from SharedPreferences.
  Future<void> _loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    _totalPoints = prefs.getInt('totalPoints') ?? 0;
    notifyListeners(); // Notify UI after loading points
  }

  /// Resets the [_isNewDay] flag, typically called after the UI has acknowledged the new day.
  void clearNewDayFlag() {
    _isNewDay = false;
    notifyListeners();
  }

  /// Start tracking steps by listening to pedometer streams.
  /// This method conditionally starts listening based on device type (physical vs. emulator)
  /// and permission status.
  Future<void> _startListening() async {
    // Determine if the app is running on a physical device or an emulator/simulator.
    bool isPhysicalDevice = true;
    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      isPhysicalDevice = androidInfo.isPhysicalDevice;
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await DeviceInfoPlugin().iosInfo;
      isPhysicalDevice = iosInfo.isPhysicalDevice;
    }

    // If it's an emulator/simulator, set pedometer as unavailable and return.
    if (!isPhysicalDevice) {
      debugPrint('Running on emulator/simulator, pedometer not available.');
      _isPedometerAvailable = false;
      // Optionally, set initial mock steps for UI testing on emulator
      // _currentSteps = 3200; // Example mock value for homepage display
      notifyListeners();
      return; // Stop here if not a physical device
    }

    // If it's a physical device, check permission status again before starting streams.
    final status = await Permission.activityRecognition.status;
    if (!status.isGranted) {
      debugPrint('Pedometer cannot start: Activity Recognition permission not granted.');
      _isPedometerAvailable = false;
      notifyListeners();
      return;
    }

    // --- Pedometer Stream Setup (only for physical devices with permission) ---

    // Listen to pedestrian status changes (e.g., walking/standing).
    _pedestrianStatusStream = Pedometer.pedestrianStatusStream;
    _pedestrianStatusStream?.listen(
      _onPedestrianStatusChanged,
      onError: _onPedestrianStatusError,
      cancelOnError: true, // Automatically stop listening if an error occurs
    );

    // Listen to step count changes.
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream?.listen(
      _onStepCount,
      onError: _onStepCountError,
      cancelOnError: true, // Automatically stop listening if an error occurs
    );

    // If we've reached this point, the pedometer should be available and listening.
    _isPedometerAvailable = true;
    notifyListeners();
  }

  /// Handle new step data received from the pedometer sensor.
  Future<void> _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Check if the date has changed since the app last recorded steps.
    // This handles cases where the app stays open overnight.
    if (prefs.getString('lastResetDate') != today) {
      await _loadBaseline(); // Trigger a full daily reset if date changed
      // After _loadBaseline, _baseSteps will be -1, and _currentSteps will be 0.
      // The next step event will set the new _baseSteps.
    }

    // If _baseSteps is -1, it means this is the first step event after a new day reset.
    if (_baseSteps == -1) {
      _baseSteps = event.steps; // Set the current event's steps as the new baseline
      await prefs.setString('lastResetDate', today); // Save current date as last reset date
      await prefs.setInt('baseSteps', _baseSteps); // Save the new baseline
      _currentSteps = 0; // Start daily steps from 0 for the new day
    } else {
      // Calculate daily steps relative to the baseline.
      _currentSteps = event.steps - _baseSteps;
      if (_currentSteps < 0) _currentSteps = 0; // Ensure steps don't go negative (can happen with sensor resets)
    }

    await _updatePoints(); // Update points based on current steps
    notifyListeners(); // Notify UI of updated steps and points
  }

  /// Update point state and persist daily steps if new points earned.
  Future<void> _updatePoints() async {
    final prefs = await SharedPreferences.getInstance();
    final cappedCurrentSteps = _currentSteps.clamp(0, maxDailySteps); // Cap steps at maxDailySteps

    // Calculate points based on previously stored daily steps and current capped steps
    final oldPointsFromStoredSteps = (_storedDailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);
    final newPointsFromCurrentSteps = (cappedCurrentSteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

    if (newPointsFromCurrentSteps > oldPointsFromStoredSteps) {
      final gainedPoints = newPointsFromCurrentSteps - oldPointsFromStoredSteps;
      _totalPoints += gainedPoints; // Add gained points to total
      _storedDailySteps = cappedCurrentSteps; // Update stored daily steps to current capped steps

      await prefs.setInt('totalPoints', _totalPoints); // Save updated total points
      await prefs.setInt('dailySteps', cappedCurrentSteps); // Save updated daily steps
    } else if (cappedCurrentSteps > _storedDailySteps) {
      // If steps increased but not enough for a new point, still update dailySteps
      _storedDailySteps = cappedCurrentSteps;
      await prefs.setInt('dailySteps', cappedCurrentSteps);
    }
  }

  /// Add mock steps (for testing purposes, especially on emulators).
  /// Mock steps are only added if the real pedometer is not active.
  Future<void> addMockSteps(int stepsToAdd) async {
    if (!_isPedometerAvailable) { // Only allow mock steps if pedometer isn't active
      _currentSteps += stepsToAdd;
      await _updatePoints(); // Update points based on mock steps
      notifyListeners(); // Notify UI of changes
    } else {
      debugPrint('Mock steps not added: Pedometer is active on this device.');
    }
  }

  /// Redeem gift card by deducting the [giftCardThreshold] from total points.
  Future<void> redeemGiftCard() async {
    if (_totalPoints >= giftCardThreshold) {
      _totalPoints -= giftCardThreshold; // Deduct points
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('totalPoints', _totalPoints); // Save updated points
      notifyListeners(); // Notify UI of point change
    }
  }

  /// Handle pedometer errors from the step count stream.
  void _onStepCountError(error) {
    debugPrint("Pedometer error: $error");
    _isPedometerAvailable = false; // Set flag to false if an error occurs
    notifyListeners(); // Notify UI that pedometer is not available
  }

  /// Handle pedometer errors from the pedestrian status stream.
  void _onPedestrianStatusError(error) {
    debugPrint("Pedestrian Status error: $error");
    _isPedometerAvailable = false; // Set flag to false if an error occurs
    notifyListeners();
  }

  /// Callback function for when pedestrian status changes.
  void _onPedestrianStatusChanged(PedestrianStatus event) {
    debugPrint('Pedestrian Status: ${event.status}');
    // You can use this status (e.g., 'walking', 'stopped') for additional UI feedback.
  }
}
