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
  /// Constants
  static const int stepsPerPoint = 100;
  static const int maxDailySteps = 10000;
  static const int maxDailyPoints = 100;
  static const int giftCardThreshold = 2500;

  /// State
  int _currentSteps = 0;
  int _baseSteps = 0;

  // Accumulates the total points earned across multiple days.
  int _totalPoints = 0;
  int _storedDailySteps = 0;
  bool _isNewDay = false;
  Stream<StepCount>? _stepCountStream;

  /// Public Getters
  int get currentSteps => _currentSteps;
  int get totalPoints => _totalPoints;

  bool get isNewDay => _isNewDay;

  /// Computed daily points (max 100)
  int get dailyPoints {
    final cappedSteps = _currentSteps.clamp(0, maxDailySteps);
    return (cappedSteps / stepsPerPoint).floor().clamp(0, maxDailyPoints);
  }

  /// Computed live total points (includes today's yet-unsaved new points)
  int get computedTotalPoints {
    final newPointsToday = dailyPoints - (_storedDailySteps ~/ stepsPerPoint);
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
    _startListening(); // Start pedometer listening conditionally
  }

  /// Permissions
  Future<void> _requestPermission() async {
    final status = await Permission.activityRecognition.request();
    if (status.isPermanentlyDenied) await openAppSettings();
  }

  /// Load base steps and daily state
  Future<void> _loadBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDate = prefs.getString('lastResetDate') ?? '';

    if (lastDate != today) {
      // It's a new day!
      _isNewDay = true;
      _baseSteps = -1;
      _storedDailySteps = 0;
      prefs.setInt('dailySteps', 0);
      prefs.setString('lastResetDate', today);
    } else {
      // Same day as last recorded activity
      _isNewDay = false;
      _baseSteps = prefs.getInt('baseSteps') ?? 0;
      _storedDailySteps = prefs.getInt('dailySteps') ?? 0;
    }
    notifyListeners(); // Notify UI after loading baseline
  }

  /// Load persisted total points
  Future<void> _loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    _totalPoints = prefs.getInt('totalPoints') ?? 0;
    notifyListeners(); // Notify UI after loading points
  }

  /// Reset daily flag
  void clearNewDayFlag() {
    _isNewDay = false;
    notifyListeners();
  }

  /// Start tracking steps
  void _startListening() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream?.listen(
      _onStepCount,
      onError: _onStepCountError,
      cancelOnError: true,
    );
  }

  /// Handle new step data
  Future<void> _onStepCount(StepCount event) async {
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

    await _updatePoints();
    notifyListeners();
  }

  /// Update point state if new points earned
  Future<void> _updatePoints() async {
    final prefs = await SharedPreferences.getInstance();
    final cappedSteps = _currentSteps.clamp(0, maxDailySteps);

    final oldPoints = (_storedDailySteps ~/ stepsPerPoint);
    final newPoints = (cappedSteps ~/ stepsPerPoint);

    if (newPoints > oldPoints) {
      final gained = newPoints - oldPoints;
      _totalPoints += gained;
      _storedDailySteps = cappedSteps;

      prefs.setInt('totalPoints', _totalPoints);
      prefs.setInt('dailySteps', cappedSteps);
    }
  }

  /// Add mock steps (for testing)
  Future<void> addMockSteps(int stepsToAdd) async {
    _currentSteps += stepsToAdd;
    await _updatePoints();
    notifyListeners();
  }

  /// Redeem gift card
  Future<void> redeemGiftCard() async {
    if (_totalPoints >= giftCardThreshold) {
      _totalPoints -= giftCardThreshold;

      final prefs = await SharedPreferences.getInstance();
      prefs.setInt('totalPoints', _totalPoints);

      notifyListeners();
    }
  }

  /// Handle pedometer errors
  void _onStepCountError(error) {
    debugPrint("Pedometer error: $error");
  }
}
