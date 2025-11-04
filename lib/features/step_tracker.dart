import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:myapp/services/database_service.dart';
import 'package:myapp/services/device_service.dart';
import 'package:myapp/services/permission_service.dart';
import 'package:myapp/services/pedometer_service.dart';
import 'package:myapp/utils/streak_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum StepStatus {
  idle,
  syncing,
  synced,
  failed,
}

/// 🟢 FIXED: No longer auto-loads in constructor
/// Data is loaded only when loadForUser() is called from main.dart
class StepTracker with ChangeNotifier {
  // --- Constants ---
  static const int stepsPerPoint = 100;
  static const int maxDailyPoints = 100;
  static const int dailyRedemptionCap = 2500;
  static const int streakStepTarget = 10000;

  // --- Internal State Variables ---
  int _rawSensorSteps = 0;
  int _dailySteps = 0;
  int _dailyStepBaseline = 0;
  int _totalPoints = 0;
  int _currentStreak = 0;
  bool _isPedometerAvailable = false;
  bool _isPhysicalDevice = true;
  bool _isNewDay = false;
  int _pointsRedeemedToday = 0;
  bool _hasClaimedToday = false;
  String? _lastClaimCheckedDate;
  StepStatus _status = StepStatus.idle;

  // State variables for UI
  bool _isLoading = true;
  int _oldSteps = 0;

  // Date helpers
  String _todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());

  String _yesterdayStr() {
    final now = DateTime.now().toLocal();
    final y = now.subtract(const Duration(days: 1));
    return DateFormat('yyyy-MM-dd').format(y);
  }

  // --- Services ---
  final _deviceService = DeviceService();
  final _permissionService = PermissionService();
  final _pedometerService = PedometerService();
  final _streakManager = StreakManager();
  final _databaseService = DatabaseService();

  // --- Timers & Lifecycle ---
  Timer? _syncTimer;
  bool _isDisposed = false;

  // 🟢 FIX: Constructor NO LONGER auto-loads data
  // Data loading is now explicit via loadForUser()
  StepTracker() {
    debugPrint('📦 StepTracker: Created (not loading yet)');
  }

  // 🟢 NEW: Generate user-specific SharedPreferences keys
  String _getPrefsKey(String key) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('⚠️ _getPrefsKey: No user logged in, using non-namespaced key');
      return key;
    }
    return '${userId}_$key'; // Prefix all keys with user ID
  }

  // --- Public Getters for UI/External Access ---
  int get currentSteps => _dailySteps;
  int get totalPoints => _totalPoints;
  int get currentStreak => _currentStreak;
  bool get isPedometerAvailable => _isPedometerAvailable;
  bool get isNewDay => _isNewDay;
  bool get canRedeemPoints => _totalPoints >= dailyRedemptionCap;
  bool get isPhysicalDevice => _isPhysicalDevice;
  bool get hasClaimedToday => _hasClaimedToday;
  String? get lastClaimCheckedDate => _lastClaimCheckedDate;
  StepStatus get status => _status;
  int get rawSensorSteps => _rawSensorSteps;
  int get dailyPointsEarned => (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);
  bool get isLoading => _isLoading;
  int get oldSteps => _oldSteps;

  // New getters to expose private variables for manual sync
  int get getTodaySteps => _dailySteps;
  int get getDailyPointsEarned => dailyPointsEarned;
  bool get hasClaimedDailyBonus => _hasClaimedToday;
  int get getStreak => _currentStreak;

  // --- Public Setters ---
  void clearNewDayFlag() {
    _isNewDay = false;
    _safeNotifyListeners();
  }

  void setCurrentSteps(int steps) {
    if (_dailySteps != steps) {
      _dailySteps = steps;
      _safeNotifyListeners();
    }
  }

  void setCurrentStreak(int streak) {
    if (_currentStreak != streak) {
      _currentStreak = streak;
      _safeNotifyListeners();
    }
  }

  void setTotalPoints(int points) {
    if (_totalPoints != points) {
      _totalPoints = points;
      _safeNotifyListeners();
    }
  }

  void setClaimedToday(bool claimed) {
    if (_hasClaimedToday != claimed) {
      _hasClaimedToday = claimed;
      _safeNotifyListeners();
    }
  }

  // 🟢 NEW: Public method to clear all state when user logs out
  void clear() {
    debugPrint('🧹 StepTracker: Clearing all state');
    _rawSensorSteps = 0;
    _dailySteps = 0;
    _dailyStepBaseline = 0;
    _totalPoints = 0;
    _currentStreak = 0;
    _isPedometerAvailable = false;
    _isPhysicalDevice = true;
    _isNewDay = false;
    _pointsRedeemedToday = 0;
    _hasClaimedToday = false;
    _lastClaimCheckedDate = null;
    _status = StepStatus.idle;
    _isLoading = true;
    _oldSteps = 0;

    // Cancel any ongoing operations
    _syncTimer?.cancel();
    _syncTimer = null;

    // 🟢 DON'T call stopListening() - the pedometer stream can't be stopped
    // The baseline approach already handles user switching correctly
    // When loadForUser() is called, it will set a new baseline automatically

    debugPrint('✅ StepTracker: State cleared');
    _safeNotifyListeners();
  }

  // 🟢 NEW: Public method to initialize data for a specific user
  // This is called from main.dart after auth is confirmed
  Future<void> loadForUser(String uid) async {
    debugPrint('👤 StepTracker: Loading data for user $uid');
    _isLoading = true;
    _safeNotifyListeners();

    try {
      _isPhysicalDevice = await _deviceService.checkIfPhysicalDevice();
      _isPedometerAvailable = await _permissionService.requestActivityPermission();

      // Load user-specific data from Firestore
      await _loadDataFromFirestore();

      if (_isPhysicalDevice && _isPedometerAvailable) {
        debugPrint('✅ Starting pedometer service for user $uid...');
        _pedometerService.startListening(
          onStepCount: _handleStepCount,
          onStepError: _handleStepError,
          onPedestrianStatusChanged: _handlePedStatus,
          onPedestrianStatusError: _handlePedStatusError,
        );
      } else {
        debugPrint('⚠️ Pedometer unavailable. Daily steps will rely on stored data only.');
      }

      _startSyncTimer();
    } catch (e, stackTrace) {
      debugPrint('❌ Initialization failed for user $uid: $e');
      debugPrint('Stack Trace: $stackTrace');
      _status = StepStatus.failed;
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // 🟢 MODIFIED: Public method for pull-to-refresh
  // Now uses the current user's UID
  Future<void> refreshData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ Cannot refresh data: No user logged in');
      return;
    }

    debugPrint('🔄 Refreshing data for user ${user.uid}');
    await _loadDataFromFirestore();
  }

  /// 🟢 FIXED: Centralized data loading from Firestore
  Future<void> _loadDataFromFirestore() async {
    _isLoading = true;
    _safeNotifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ No user logged in, skipping data load');
      _isLoading = false;
      _safeNotifyListeners();
      return;
    }

    try {
      final today = _todayStr();
      final data = await _databaseService.getDailyStatsOnce(today);

      if (data != null) {
        final stepsFromDb = data['steps'] ?? 0;
        final streakFromDb = (data['streak'] as int?) ?? 0;
        final claimedFromDb = data['claimedDailyBonus'] == true;

        debugPrint('📊 Steps: $stepsFromDb, Streak: $streakFromDb, Daily Points: ${data['dailyPointsEarned']}');

        // 🟢 FIX: Set steps and also initialize SharedPreferences
        setCurrentSteps(stepsFromDb);
        setCurrentStreak(streakFromDb);
        setClaimedToday(claimedFromDb);

        // 🟢 CRITICAL FIX: Initialize SharedPreferences with USER-SPECIFIC keys
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_getPrefsKey('lastResetDate'), today);
        await prefs.setInt(_getPrefsKey('dailySteps'), stepsFromDb);
        await prefs.setInt(_getPrefsKey('currentStreak'), streakFromDb);

        // 🟢 Set oldSteps for animation
        _oldSteps = stepsFromDb;

        debugPrint('✅ Initialized SharedPreferences for pedometer sensor (user-namespaced)');
      } else {
        // No data in Firestore for today, check local state
        await _loadBaselineAndStreak();
      }

      // Load total points separately
      await loadTotalPointsFromDB();
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading data from Firestore: $e');
      debugPrint('Stack Trace: $stackTrace');
      // Fallback to local data
      await _loadBaselineAndStreak();
      await loadTotalPointsFromDB();
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // This method is called as a fallback if Firestore fails or if it's a new day
  Future<void> _loadBaselineAndStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();
    final lastDate = prefs.getString(_getPrefsKey('lastResetDate')) ?? '';

    debugPrint('📊 Evaluating streak and loading baseline for $today...');

    if (lastDate != today) {
      debugPrint('🔄 New day detected. Resetting daily stats and evaluating streak.');
      _isNewDay = true;
      _dailySteps = 0;
      _dailyStepBaseline = 0;
      await prefs.setInt(_getPrefsKey('dailySteps'), 0);
      await prefs.setInt(_getPrefsKey('dailyStepBaseline'), 0);
      await prefs.remove(_getPrefsKey('lastRecordedRawSensorSteps'));

      _currentStreak = await StreakManager.evaluateForNewDay(
        today: today,
        prefs: prefs,
        db: _databaseService,
        streakTarget: streakStepTarget,
      );

      await prefs.setString(_getPrefsKey('lastResetDate'), today);
      setClaimedToday(false);
    } else {
      _dailySteps = prefs.getInt(_getPrefsKey('dailySteps')) ?? 0;
      _dailyStepBaseline = prefs.getInt(_getPrefsKey('dailyStepBaseline')) ?? 0;
      _currentStreak = await _databaseService.getUserProfileStreak();
      await prefs.setInt(_getPrefsKey('currentStreak'), _currentStreak);

      debugPrint('📅 Same day. Loaded dailySteps: $_dailySteps, baseline: $_dailyStepBaseline, streak: $_currentStreak');
    }

    await _checkIfClaimedToday(today);
  }

  Future<void> loadTotalPointsFromDB() async {
    try {
      _totalPoints = await _databaseService.getTotalPointsFromUserProfile();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_getPrefsKey('totalPoints'), _totalPoints);
      _safeNotifyListeners();
      debugPrint('💰 Synced totalPoints from DB: $_totalPoints');
    } catch (e) {
      debugPrint('❌ Error loading totalPoints from DB: $e. Falling back to SharedPreferences.');
      final prefs = await SharedPreferences.getInstance();
      _totalPoints = prefs.getInt(_getPrefsKey('totalPoints')) ?? 0;
      _safeNotifyListeners();
    }
  }

  Future<void> _persistTodayStats({
    required String date,
    required SharedPreferences prefs,
  }) async {
    await _databaseService.saveStatsAndPoints(
      date: date,
      steps: _dailySteps,
      dailyPointsEarned: dailyPointsEarned,
      streak: _currentStreak,
      claimedDailyBonus: _hasClaimedToday,
    );
  }

  Future<void> _checkIfClaimedToday(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final lastChecked = prefs.getString(_getPrefsKey('lastClaimCheckedDate'));

    if (lastChecked == date && _hasClaimedToday) return;

    try {
      final snapshot = await _databaseService.getDailyStatsOnce(date);
      final claimed = snapshot != null &&
          (snapshot['claimedDailyBonus'] == true ||
              snapshot['dailyPointsEarned'] >= maxDailyPoints);

      setClaimedToday(claimed);

      if (kDebugMode) {
        debugPrint('📦 Daily bonus claim check: $claimed (from DB)');
      }
    } catch (e, stack) {
      debugPrint('❌ Error checking daily bonus claim: $e\n$stack');
    }

    _lastClaimCheckedDate = date;
    await prefs.setString(_getPrefsKey('lastClaimCheckedDate'), date);
  }

  // --- Step Counting Logic (for actual Pedometer sensor) ---
  void _handleStepCount(int cumulativeStepsFromSensor) async {
    _rawSensorSteps = cumulativeStepsFromSensor;
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();
    final lastDate = prefs.getString(_getPrefsKey('lastResetDate')) ?? '';

    debugPrint('👣 [Sensor] Incoming: $cumulativeStepsFromSensor. Last Reset Date: $lastDate. Today: $today');

    // 🟢 NEW DAY DETECTION
    if (today != lastDate) {
      debugPrint('🔄 [Sensor] Detected new day. Applying new day logic.');
      _isNewDay = true;

      // 🟢 CRITICAL FIX: Check if we already loaded data from Firebase
      final hasLoadedData = _dailySteps > 0;

      if (hasLoadedData) {
        debugPrint('✅ [Sensor] Data already loaded from Firebase (_dailySteps=$_dailySteps)');
        debugPrint('🔧 [Sensor] Setting baseline without resetting steps');

        // Just set the baseline to current sensor value
        _dailyStepBaseline = cumulativeStepsFromSensor;
        await prefs.setInt(_getPrefsKey('dailyStepBaseline'), _dailyStepBaseline);
        await prefs.setString(_getPrefsKey('lastResetDate'), today);
        await prefs.setInt(_getPrefsKey('dailySteps'), _dailySteps);

        await _checkIfClaimedToday(today);
        return;
      }

      // 🟢 NO DATA LOADED: Normal new day reset logic
      debugPrint('🆕 [Sensor] No data loaded, performing fresh day initialization');
      _dailySteps = 0;
      _dailyStepBaseline = cumulativeStepsFromSensor;
      await prefs.setInt(_getPrefsKey('dailySteps'), 0);
      await prefs.setInt(_getPrefsKey('dailyStepBaseline'), _dailyStepBaseline);
      await prefs.setString(_getPrefsKey('lastResetDate'), today);
      await prefs.remove(_getPrefsKey('lastRecordedRawSensorSteps'));

      // Delegate streak new-day evaluation
      _currentStreak = await StreakManager.evaluateForNewDay(
        today: today,
        prefs: prefs,
        db: _databaseService,
        streakTarget: streakStepTarget,
      );

      setClaimedToday(false);
      await _checkIfClaimedToday(today);
    } else {
      // 🟢 SAME DAY: Initialize or update baseline

      if (_dailyStepBaseline == 0 && cumulativeStepsFromSensor > 0) {
        final lastSavedDailySteps = prefs.getInt(_getPrefsKey('dailySteps')) ?? 0;
        final lastRecordedRawSensorSteps = prefs.getInt(_getPrefsKey('lastRecordedRawSensorSteps')) ?? 0;

        // 🟢 FIX: If we have loaded steps, use them
        final effectiveDailySteps = _dailySteps > 0 ? _dailySteps : lastSavedDailySteps;

        if (lastRecordedRawSensorSteps > 0 && cumulativeStepsFromSensor >= lastRecordedRawSensorSteps) {
          _dailyStepBaseline = lastRecordedRawSensorSteps - effectiveDailySteps;
          debugPrint('🎯 [Sensor] Inferred _dailyStepBaseline: $_dailyStepBaseline (from prefs data)');
        } else {
          _dailyStepBaseline = cumulativeStepsFromSensor - effectiveDailySteps;
          debugPrint('⚠️ [Sensor] Fallback: Inferred _dailyStepBaseline: $_dailyStepBaseline (from current sensor and stored daily)');
        }

        await prefs.setInt(_getPrefsKey('dailyStepBaseline'), _dailyStepBaseline);
        debugPrint('✅ [Sensor] Baseline set to $_dailyStepBaseline for current steps: $effectiveDailySteps');
      } else if (_dailyStepBaseline == 0) {
        // 🟢 FIX: If we have loaded steps but no baseline, calculate baseline
        final effectiveDailySteps = _dailySteps > 0 ? _dailySteps : 0;
        _dailyStepBaseline = cumulativeStepsFromSensor - effectiveDailySteps;
        await prefs.setInt(_getPrefsKey('dailyStepBaseline'), _dailyStepBaseline);
        debugPrint('🔄 [Sensor] Calculated baseline: $cumulativeStepsFromSensor - $effectiveDailySteps = $_dailyStepBaseline');
      }

      _currentStreak = prefs.getInt(_getPrefsKey('currentStreak')) ?? _currentStreak;
    }

    // 🟢 CALCULATE NEW STEPS
    final int calculatedDailySteps = (cumulativeStepsFromSensor - _dailyStepBaseline).clamp(0, 10000000);

    if (calculatedDailySteps > _dailySteps) {
      debugPrint('✨ [Sensor] New steps detected: $calculatedDailySteps > $_dailySteps');
      final oldPointsEarned = dailyPointsEarned;
      _dailySteps = calculatedDailySteps;
      final newPointsEarned = dailyPointsEarned;
      final newPointsFromSteps = newPointsEarned - oldPointsEarned;

      if (newPointsFromSteps > 0) {
        _totalPoints += newPointsFromSteps;
        await prefs.setInt(_getPrefsKey('totalPoints'), _totalPoints);
        debugPrint('💰 Added $newPointsFromSteps new points from steps. Total: $_totalPoints');
      }

      await prefs.setInt(_getPrefsKey('dailySteps'), _dailySteps);
      await prefs.setInt(_getPrefsKey('lastRecordedRawSensorSteps'), cumulativeStepsFromSensor);
      _safeNotifyListeners();

      // Delegate "credit today if target met" to StreakManager
      _currentStreak = await StreakManager.tryCreditTodayIfTargetMet(
        todaySteps: _dailySteps,
        dailyPointsEarned: dailyPointsEarned,
        hasClaimedBonus: _hasClaimedToday,
        today: today,
        currentStreak: _currentStreak,
        prefs: prefs,
        db: _databaseService,
        streakTarget: streakStepTarget,
      );

      _safeNotifyListeners();
    } else {
      debugPrint('🚫 [Sensor] No significant new steps for UI update. Calculated: $calculatedDailySteps, Current: $_dailySteps');
    }
  }

  // --- UI Data Retrieval ---
  Future<Map<String, dynamic>?> getDailyStatsForUI(String date) async {
    try {
      final data = await _databaseService.getDailyStatsOnce(date);
      debugPrint('📊 UI Data Request: Fetched daily stats for $date: ${data != null ? 'Found' : 'Not Found'}');
      return data;
    } catch (e, stackTrace) {
      debugPrint('❌ StepTracker.getDailyStatsForUI error: $e');
      debugPrint('Stack Trace: $stackTrace');
      return null;
    }
  }

  // --- Background Sync ---
  void _startSyncTimer() {
    int lastSyncedSteps = -1;
    int lastSyncedPoints = -1;
    bool lastSyncedClaimStatus = false;

    _syncTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      if (_isDisposed) return;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());

      if (_dailySteps != lastSyncedSteps ||
          _totalPoints != lastSyncedPoints ||
          _hasClaimedToday != lastSyncedClaimStatus) {
        _status = StepStatus.syncing;
        _safeNotifyListeners();
        debugPrint('🔄 Initiating background sync: Daily Steps: $_dailySteps, Total Points: $_totalPoints, Claimed Today: $_hasClaimedToday');

        try {
          await _databaseService.saveStatsAndPoints(
            date: today,
            steps: _dailySteps,
            dailyPointsEarned: dailyPointsEarned,
            streak: _currentStreak,
            claimedDailyBonus: _hasClaimedToday,
          );

          lastSyncedSteps = _dailySteps;
          lastSyncedPoints = _totalPoints;
          lastSyncedClaimStatus = _hasClaimedToday;

          _status = StepStatus.synced;
          debugPrint('✅ Background sync successful: Daily Steps: $lastSyncedSteps, Total Points: $lastSyncedPoints, Claimed Today: $lastSyncedClaimStatus');
        } catch (e, stackTrace) {
          _status = StepStatus.failed;
          debugPrint('❌ Background sync failed: $e');
          debugPrint('Stack Trace: $stackTrace');
        } finally {
          _safeNotifyListeners();
        }
      } else {
        debugPrint('✅ No changes to sync. Skipping background sync.');
      }
    });
  }

  // --- Point Earning Logic for Daily Bonus Claim ---
  Future<void> claimDailyBonusPoints() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());

    if (_hasClaimedToday) {
      debugPrint('🚫 Claim rejected. Already claimed for today.');
      return;
    }

    if (dailyPointsEarned < maxDailyPoints) {
      debugPrint('🚫 Claim rejected. Not enough steps ($_dailySteps) to earn max daily points ($maxDailyPoints).');
      return;
    }

    try {
      await _databaseService.claimDailyPoints();
      await loadTotalPointsFromDB();
      setClaimedToday(true);
      debugPrint('✅ Claimed daily bonus. New total points: $_totalPoints');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to claim bonus: $e');
      debugPrint('Stack Trace: $stackTrace');
      setClaimedToday(false);
    } finally {
      _safeNotifyListeners();
    }
  }

  // --- Point Redemption Logic ---
  Future<int> redeemPoints(int pointsToRedeem) async {
    if (_totalPoints < pointsToRedeem) {
      debugPrint('🚫 Cannot redeem points: Insufficient points. Total: $_totalPoints, Needed: $pointsToRedeem');
      return 0;
    }

    try {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
      final success = await _databaseService.redeemDailyPoints(
        date: date,
        pointsToRedeem: pointsToRedeem,
        currentTotalPoints: _totalPoints - pointsToRedeem,
      );

      if (success) {
        _totalPoints -= pointsToRedeem;
        _pointsRedeemedToday += pointsToRedeem;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_getPrefsKey('totalPoints'), _totalPoints);
        debugPrint('✅ Points redeemed successfully. Total points: $_totalPoints');
        return pointsToRedeem;
      } else {
        debugPrint('❌ Redemption failed to sync to database.');
        return 0;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Redeem failed: $e');
      debugPrint('Stack Trace: $stackTrace');
      return 0;
    } finally {
      _safeNotifyListeners();
    }
  }

  // --- Manual Reset ---
  Future<void> resetSteps() async {
    debugPrint('🔁 Manually resetting steps and related data...');
    _dailySteps = 0;
    _dailyStepBaseline = 0;
    _rawSensorSteps = 0;
    _pointsRedeemedToday = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_getPrefsKey('dailySteps'), 0);
    await prefs.setInt(_getPrefsKey('dailyStepBaseline'), 0);
    await prefs.remove(_getPrefsKey('lastRecordedRawSensorSteps'));

    setClaimedToday(false);
    _isNewDay = true;
    _safeNotifyListeners();

    debugPrint('✅ Steps manually reset to 0 (and baseline/redeemed status).');
  }

  // --- Pedometer Error & Status Handlers ---
  void _handleStepError(dynamic error) {
    debugPrint('Step count error: $error');
    _isPedometerAvailable = false;
    _safeNotifyListeners();
  }

  void _handlePedStatus(String status) {
    debugPrint('🚶 Pedestrian status: $status');
  }

  void _handlePedStatusError(dynamic error) {
    debugPrint('Pedestrian status error: $error');
    _isPedometerAvailable = false;
    _safeNotifyListeners();
  }

  // --- External Mock Step Control (Debug Only) ---
  Future<void> addMockSteps(int stepsToAdd) async {
    if (kDebugMode) {
      _dailySteps += stepsToAdd;
      debugPrint('📈 [Mock] Added $stepsToAdd steps. New _dailySteps: $_dailySteps');

      final oldPointsEarned = dailyPointsEarned;
      final newPointsEarned = (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

      if (newPointsEarned > oldPointsEarned) {
        _totalPoints += (newPointsEarned - oldPointsEarned);
        await SharedPreferences.getInstance().then((prefs) {
          prefs.setInt(_getPrefsKey('totalPoints'), _totalPoints);
        });
        debugPrint('💰 [Mock] Gained ${newPointsEarned - oldPointsEarned} points. Total points: $_totalPoints');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_getPrefsKey('dailySteps'), _dailySteps);

      // Delegate crediting to StreakManager
      final today = _todayStr();
      _currentStreak = await StreakManager.tryCreditTodayIfTargetMet(
        todaySteps: _dailySteps,
        dailyPointsEarned: dailyPointsEarned,
        hasClaimedBonus: _hasClaimedToday,
        today: today,
        currentStreak: _currentStreak,
        prefs: prefs,
        db: _databaseService,
        streakTarget: streakStepTarget,
      );

      // Optionally sync to DB for verification
      try {
        await _databaseService.saveStatsAndPoints(
          date: today,
          steps: _dailySteps,
          dailyPointsEarned: dailyPointsEarned,
          streak: _currentStreak,
          claimedDailyBonus: _hasClaimedToday,
        );
        debugPrint('✅ [Mock] Steps synced to database for verification.');
      } catch (e, stackTrace) {
        debugPrint('❌ [Mock] Failed to sync mock steps to database: $e');
        debugPrint('Stack Trace: $stackTrace');
      }

      _safeNotifyListeners();
    } else {
      debugPrint('🚫 Mock steps are only allowed in debug mode. Current mode: ${kReleaseMode ? "Release" : "Profile"}');
    }
  }

  Future<void> resetMockSteps() async {
    if (kDebugMode) {
      debugPrint('🧹 [Mock] Resetting mock steps to 0.');
      _dailySteps = 0;
      _dailyStepBaseline = 0;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_getPrefsKey('dailySteps'), 0);
      await prefs.setInt(_getPrefsKey('dailyStepBaseline'), 0);
      await prefs.remove(_getPrefsKey('lastRecordedRawSensorSteps'));

      setClaimedToday(false);

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
      try {
        await _databaseService.saveStatsAndPoints(
          date: today,
          steps: _dailySteps,
          dailyPointsEarned: dailyPointsEarned,
          streak: _currentStreak,
          claimedDailyBonus: false,
        );
        debugPrint('✅ [Mock] Step reset synced to database.');
      } catch (e, stackTrace) {
        debugPrint('❌ [Mock] Failed to sync reset: $e');
        debugPrint('Stack Trace: $stackTrace');
      }

      _safeNotifyListeners();
    } else {
      debugPrint('🚫 resetMockSteps is only available in debug mode.');
    }
  }

  // --- Utilities ---
  void _safeNotifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _isDisposed = true;
    super.dispose();
  }
}
