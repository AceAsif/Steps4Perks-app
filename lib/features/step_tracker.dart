import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:device_info_plus/device_info_plus.dart'; // Provides device information (e.g., if it's a physical device vs. emulator)
import 'package:flutter/foundation.dart'; // Contains defaultTargetPlatform for platform checks

/// Manages step tracking, point accumulation, and daily resets for the Steps4Perks app.
///
/// This class extends [ChangeNotifier] to allow its state to be observed by widgets.
/// When its internal state changes (e.g., current steps, total points), it calls
/// [notifyListeners()] to rebuild dependent UI components.
class StepTracker with ChangeNotifier {
  // --- Private State Variables ---

  // Stores the current number of steps taken today relative to the baseline.
  int _currentSteps = 0;
  // Getter for [_currentSteps] to expose it to widgets.
  int get currentSteps => _currentSteps;

  // Stores the initial step count from the pedometer sensor when tracking starts for the day.
  // Used to calculate daily steps: `event.steps - _baseSteps`.
  int _baseSteps = 0;

  // Accumulates the total points earned across multiple days.
  int _totalPoints = 0;
  // Getter for [_totalPoints] to expose it to widgets.
  int get totalPoints => _totalPoints;

  // Flag to indicate if a new day has started since the last app open/reset.
  // Used primarily for UI notifications (e.g., "Your steps have reset!").
  bool _isNewDay = false;
  // Getter for [_isNewDay].
  bool get isNewDay => _isNewDay;

  // Stream for raw step count data from the pedometer plugin.
  Stream<StepCount>? _stepCountStream;
  // Stream for pedestrian status (e.g., walking, standing) from the pedometer plugin.
  Stream<PedestrianStatus>? _pedestrianStatusStream;

  // Flag to indicate if the pedometer sensor is actually available and working on the device.
  // This is crucial for distinguishing between physical devices and emulators.
  bool _isPedometerAvailable = false;
  // Getter for [_isPedometerAvailable].
  bool get isPedometerAvailable => _isPedometerAvailable;

  // --- Constants for Game Logic ---

  // Number of steps required to earn 1 point.
  static const int stepsPerPoint = 100;
  // Maximum daily steps that will count towards earning points.
  static const int maxDailySteps = 10000;
  // Threshold of total points required to redeem a gift card (e.g., 2500 points for $25 if 100 points = $1).
  static const int giftCardThreshold = 2500;

  // --- Constructor ---

  /// Constructor for [StepTracker]. It calls the [_init] method to set up the tracker.
  StepTracker() {
    _init();
  }

  // --- Initialization Methods ---

  /// Initializes the step tracker by requesting permissions, loading saved data,
  /// and starting to listen to pedometer events.
  Future<void> _init() async {
    await _requestPermission(); // Request activity recognition permission
    await _loadBaseline(); // Load last reset date and base steps
    await _loadPoints(); // Load accumulated points
    await _startListening(); // Start pedometer listening conditionally
  }

  /// Requests the 'activityRecognition' permission, which is necessary for pedometer access.
  /// If the permission is permanently denied, it guides the user to app settings.
  Future<void> _requestPermission() async {
    final status = await Permission.activityRecognition.request();
    if (status.isPermanentlyDenied) {
      debugPrint('Activity Recognition permission permanently denied. Guiding user to settings.');
      await openAppSettings(); // Open app settings for user to manually enable permission
    }
    // Update the availability flag based on initial permission status
    _isPedometerAvailable = status.isGranted;
    if (!status.isGranted) {
      debugPrint('Activity Recognition permission not granted.');
    }
    notifyListeners(); // Notify UI about permission status change
  }

  /// Starts listening to pedometer streams, but only if the device is a physical device
  /// and activity recognition permission is granted.
  Future<void> _startListening() async {
    // Determine if the app is running on a physical device or an emulator/simulator.
    // Pedometer sensors are typically not available on emulators.
    bool isPhysicalDevice = true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      isPhysicalDevice = androidInfo.isPhysicalDevice;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IosDeviceInfo iosInfo = await DeviceInfoPlugin().iosInfo;
      isPhysicalDevice = iosInfo.isPhysicalDevice;
    }

    // If it's an emulator/simulator, set pedometer as unavailable and return.
    if (!isPhysicalDevice) {
      debugPrint('Running on emulator/simulator, pedometer not available.');
      _isPedometerAvailable = false;
      _currentSteps = 0; // Reset current steps for emulator display
      notifyListeners();
      return;
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

  // --- Testing/Debugging Methods ---

  /// Allows adding mock steps for testing purposes, especially on emulators
  /// where the actual pedometer sensor is not available.
  /// Mock steps are only added if the real pedometer is not active.
  void addMockSteps(int stepsToAdd) async {
    if (!_isPedometerAvailable) { // Only allow mock steps if pedometer isn't active
      _currentSteps += stepsToAdd;

      final prefs = await SharedPreferences.getInstance();
      final storedDailySteps = prefs.getInt('dailySteps') ?? 0; // Steps stored from previous mock additions

      // Cap the current steps to maxDailySteps for point calculation
      final cappedCurrentSteps = _currentSteps.clamp(0, maxDailySteps);

      // Calculate points based on the capped steps
      final oldPointsFromDailySteps = (storedDailySteps) ~/ stepsPerPoint;
      final newPointsFromDailySteps = (cappedCurrentSteps) ~/ stepsPerPoint;

      // If new points are gained, add them to totalPoints
      if (newPointsFromDailySteps > oldPointsFromDailySteps) {
        final gainedPoints = newPointsFromDailySteps - oldPointsFromDailySteps;
        _totalPoints += gainedPoints;
        await prefs.setInt('totalPoints', _totalPoints);
      }
      // Always update the dailySteps in SharedPreferences with the capped value
      await prefs.setInt('dailySteps', cappedCurrentSteps);

      notifyListeners(); // Notify UI of changes
    } else {
      debugPrint('Mock steps not added: Pedometer is active on this device.');
    }
  }

  // --- Data Loading and Reset Logic ---

  /// Loads the baseline steps and checks if a new day has started.
  /// Resets daily steps if a new day is detected.
  Future<void> _loadBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString('lastResetDate') ?? ''; // Date of last reset
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now()); // Current date

    if (lastDate != today) {
      // It's a new day!
      _isNewDay = true;
      _baseSteps = -1; // Flag to indicate that _baseSteps needs to be set from the first step event
      _currentSteps = 0; // Reset current steps displayed for the new day
      await prefs.setInt('dailySteps', 0); // Reset daily steps in storage
      await prefs.setString('lastResetDate', today); // Update last reset date
      // Note: _totalPoints are NOT reset here, as they accumulate across days.
    } else {
      // Same day as last recorded activity
      _isNewDay = false;
      _baseSteps = prefs.getInt('baseSteps') ?? 0; // Load previous base steps
      _currentSteps = prefs.getInt('dailySteps') ?? 0; // Load previous daily steps
    }
    notifyListeners(); // Notify UI after loading baseline
  }

  /// Clears the [_isNewDay] flag, typically called after the UI has acknowledged the new day.
  void clearNewDayFlag() {
    _isNewDay = false;
    notifyListeners();
  }

  /// Loads the accumulated total points from SharedPreferences.
  Future<void> _loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    _totalPoints = prefs.getInt('totalPoints') ?? 0;
    notifyListeners(); // Notify UI after loading points
  }

  // --- Getters for UI Display ---

  /// Calculates the current daily points earned based on capped steps.
  int get dailyPoints {
    final cappedSteps = _currentSteps.clamp(0, maxDailySteps);
    return (cappedSteps / stepsPerPoint).floor();
  }

  /// Checks if the user has enough total points to redeem a gift card.
  bool get canRedeemGiftCard => _totalPoints >= giftCardThreshold;

  // --- Reward Redemption Logic ---

  /// Redeems a gift card by deducting the [giftCardThreshold] from total points.
  void redeemGiftCard() async {
    if (_totalPoints >= giftCardThreshold) {
      _totalPoints -= giftCardThreshold; // Deduct points
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('totalPoints', _totalPoints); // Save updated points
      notifyListeners(); // Notify UI of point change
    }
  }

  // --- Pedometer Stream Callbacks ---

  /// Callback function for when a new step count event is received from the pedometer.
  void _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Check if the date has changed since the app last recorded steps.
    // This handles cases where the app stays open overnight.
    if (prefs.getString('lastResetDate') != today) {
      await _loadBaseline(); // Trigger a full daily reset if date changed
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

    final storedDailySteps = prefs.getInt('dailySteps') ?? 0; // Steps stored from previous session/update
    final cappedCurrentSteps = _currentSteps.clamp(0, maxDailySteps); // Cap steps at maxDailySteps

    // Calculate points gained since the last update
    final oldPointsFromDailySteps = (storedDailySteps) ~/ stepsPerPoint;
    final newPointsFromDailySteps = (cappedCurrentSteps) ~/ stepsPerPoint;

    if (newPointsFromDailySteps > oldPointsFromDailySteps) {
      final gainedPoints = newPointsFromDailySteps - oldPointsFromDailySteps;
      _totalPoints += gainedPoints; // Add gained points to total
      await prefs.setInt('totalPoints', _totalPoints); // Save updated total points
    }

    // Always update the stored daily steps with the capped current steps
    await prefs.setInt('dailySteps', cappedCurrentSteps);

    notifyListeners(); // Notify UI of updated steps and points
  }

  /// Callback function for errors from the step count stream.
  void _onStepCountError(error) {
    debugPrint("Pedometer error: $error");
    _isPedometerAvailable = false; // Set flag to false if an error occurs
    notifyListeners(); // Notify UI that pedometer is not available
    // The `cancelOnError: true` in `_startListening` will stop the stream here.
    // You might want to display a user-friendly message on the UI.
  }

  /// Callback function for when pedestrian status changes.
  void _onPedestrianStatusChanged(PedestrianStatus event) {
    debugPrint('Pedestrian Status: ${event.status}');
    // You can use this status (e.g., 'walking', 'stopped') for additional UI feedback.
  }

  /// Callback function for errors from the pedestrian status stream.
  void _onPedestrianStatusError(error) {
    debugPrint("Pedestrian Status error: $error");
    _isPedometerAvailable = false; // Set flag to false if an error occurs
    notifyListeners();
  }
}
