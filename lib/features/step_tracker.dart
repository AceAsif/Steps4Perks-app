import 'dart:async';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:myapp/services/database_service.dart';
import 'package:myapp/services/device_service.dart';
import 'package:myapp/services/permission_service.dart';
import 'package:myapp/services/pedometer_service.dart';
import 'package:myapp/utils/streak_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

enum StepStatus {
  idle,
  syncing,
  synced,
  failed,
}

class StepTracker with ChangeNotifier {
  // --- Constants ---
  static const int stepsPerPoint = 100;
  static const int maxDailyPoints = 100; // Max points earnable from steps per day
  static const int dailyRedemptionCap = 2500; // Max points redeemable per day (for spending, not earning)
  static const int streakStepTarget = 10000; //Streak target
  static const String _kStreakCreditedFor = 'streakCreditedFor'; // Key used in SharedPreferences to prevent double-increment in a day

  // --- Internal State Variables ---
  int _rawSensorSteps = 0;      // Cumulative steps directly from the sensor/pedometer API
  int _dailySteps = 0;          // Steps counted for the current day (0-based for the day)
  int _dailyStepBaseline = 0;   // The _rawSensorSteps value at the start of the current day's counting
  int _totalPoints = 0;         // Overall accumulated points (now authoritative from main user profile)
  int _currentStreak = 0;
  bool _isPedometerAvailable = false;
  bool _isPhysicalDevice = true; // Determined by DeviceService
  bool _isNewDay = false;       // Flag set when a new calendar day is detected
  int _pointsRedeemedToday = 0; // Points redeemed today from the daily cap (for spending)

  bool _hasClaimedToday = false;    // Whether today's daily bonus points have been claimed
  String? _lastClaimCheckedDate;    // Last date we checked claim status from DB
  StepStatus _status = StepStatus.idle; // Sync status for UI feedback

  //Date helpers
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
  final _databaseService = DatabaseService(); // DatabaseService instance

  // --- Timers & Lifecycle ---
  Timer? _syncTimer;
  bool _isDisposed = false;

  // --- Constructor ---
  StepTracker() {
    _init();
  }

  // --- Public Getters for UI/External Access ---
  int get currentSteps => _dailySteps;
  int get totalPoints => _totalPoints;
  int get currentStreak => _currentStreak;
  bool get isPedometerAvailable => _isPedometerAvailable;
  bool get isNewDay => _isNewDay;
  // canRedeemPoints now refers to whether a single reward (costing 'dailyRedemptionCap' if fixed) can be redeemed.
  // The actual check should be against a specific reward's cost.
  // This getter might need to be re-evaluated depending on actual UI usage.
  // For now, it will check if currentTotalPoints is enough for a fixed 'dailyRedemptionCap' cost.
  bool get canRedeemPoints => _totalPoints >= dailyRedemptionCap; // This getter is for the fixed "dailyRedemptionCap" example in `redeemPoints()`
  bool get isPhysicalDevice => _isPhysicalDevice;
  bool get hasClaimedToday => _hasClaimedToday; // For daily bonus claim
  String? get lastClaimCheckedDate => _lastClaimCheckedDate;
  StepStatus get status => _status;
  int get rawSensorSteps => _rawSensorSteps;
  // Calculate daily points earned based on _dailySteps, clamped to maxDailyPoints
  int get dailyPointsEarned => (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

  // --- Public Setters (if needed for external control/mocking in UI) ---
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
    // This setter is primarily for internal updates and initial loading.
    // Direct external modification of _totalPoints should go through `claimDailyBonusPoints` or `redeemPoints`.
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

  // --- Initialization and Loading ---

  Future<void> _init() async {
    try {
      _isPhysicalDevice = await _deviceService.checkIfPhysicalDevice();
      _isPedometerAvailable = await _permissionService.requestActivityPermission();

      await _loadBaselineAndStreak(); // Combined loading for clarity
      await loadTotalPointsFromDB(); // Load overall total points from DB (renamed from _loadTotalPoints)

      if (_isPhysicalDevice && _isPedometerAvailable) {
        debugPrint('✅ Starting pedometer service...');
        _pedometerService.startListening(
          onStepCount: _handleStepCount,
          onStepError: _handleStepError,
          onPedestrianStatusChanged: _handlePedStatus,
          onPedestrianStatusError: _handlePedStatusError,
        );
      } else {
        debugPrint('⚠️ Pedometer unavailable or permission denied/not a physical device. Daily steps will rely on stored data only.');
      }

      _startSyncTimer();
      _safeNotifyListeners(); // Notify initial state after all loading
    } catch (e, stackTrace) {
      debugPrint('❌ Initialization failed: $e');
      debugPrint('Stack Trace: $stackTrace');
      _status = StepStatus.failed;
      _safeNotifyListeners();
    }
  }

  Future<void> _loadBaselineAndStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();
    final lastDate = prefs.getString('lastResetDate') ?? '';

    debugPrint('📊 Evaluating streak and loading baseline for $today...');

    if (lastDate != today) {
      debugPrint('🔄 New day detected. Resetting daily stats and evaluating streak.');
      _isNewDay = true;

      // Reset daily counters for the new day
      _dailySteps = 0;
      _dailyStepBaseline = 0;
      await prefs.setInt('dailySteps', 0);
      await prefs.setInt('dailyStepBaseline', 0);
      await prefs.remove('lastRecordedRawSensorSteps');

      // ✅ Decide "met yesterday" using the local credited flag first, then DB fallback
      final yesterday = _yesterdayStr();
      final creditedFor = prefs.getString(_kStreakCreditedFor);
      final metYesterdayLocally = (creditedFor == yesterday);
      bool metYesterday = metYesterdayLocally;

      if (!metYesterdayLocally) {
        int yesterdaySteps = 0;
        try {
          final yDoc = await _databaseService.getDailyStatsOnce(yesterday);
          if (yDoc != null) {
            final s = yDoc['steps'];
            if (s is int) {
              yesterdaySteps = s;
            } else if (s is double) {
              yesterdaySteps = s.toInt();
            }
          }
        } catch (_) {}
        metYesterday = yesterdaySteps >= streakStepTarget;
      }

      if (!metYesterday) {
        // Missed yesterday → reset streak
        _currentStreak = 0;
        await _databaseService.setUserProfileStreak(_currentStreak);
        await prefs.setInt('currentStreak', _currentStreak);
        debugPrint('❌ Yesterday missed → streak reset to 0');
      } else {
        // Met yesterday → keep streak as-is (up to yesterday)
        _currentStreak = await _databaseService.getUserProfileStreak();
        if (_currentStreak == 0) {
          _currentStreak = prefs.getInt('currentStreak') ?? 0;
        }
        await prefs.setInt('currentStreak', _currentStreak);
        debugPrint('✅ Yesterday met → keep streak at $_currentStreak');
      }

      // New day bookkeeping
      await prefs.setString('lastResetDate', today);
      await prefs.remove(_kStreakCreditedFor); // enable today's 10k credit
      setClaimedToday(false);
    } else {
      // Same day: load existing data
      _dailySteps = prefs.getInt('dailySteps') ?? 0;
      _dailyStepBaseline = prefs.getInt('dailyStepBaseline') ?? 0;

      // Prefer canonical streak from profile; cache to prefs
      _currentStreak = await _databaseService.getUserProfileStreak();
      await prefs.setInt('currentStreak', _currentStreak);

      debugPrint('📅 Same day. Loaded dailySteps: $_dailySteps, baseline: $_dailyStepBaseline, streak: $_currentStreak');
    }

    await _checkIfClaimedToday(today);
  }

  // MODIFIED: loadTotalPointsFromDB - now public and fetches from DatabaseService
  Future<void> loadTotalPointsFromDB() async {
    try {
      _totalPoints = await _databaseService.getTotalPointsFromUserProfile();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('totalPoints', _totalPoints); // Keep local cache updated
      _safeNotifyListeners();
      debugPrint('💰 Synced totalPoints from DB: $_totalPoints');
    } catch (e) {
      debugPrint('❌ Error loading totalPoints from DB: $e. Falling back to SharedPreferences.');
      final prefs = await SharedPreferences.getInstance();
      _totalPoints = prefs.getInt('totalPoints') ?? 0;
      _safeNotifyListeners();
    }
  }
  // Mirror today's live state to Firestore.dailyStats
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

  // Helper for checkIfClaimedToday, internal to StepTracker
  Future<void> _checkIfClaimedToday(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final lastChecked = prefs.getString('lastClaimCheckedDate');

    if (lastChecked == date && _hasClaimedToday) return;

    try {
      final snapshot = await _databaseService.getDailyStatsOnce(date);
      final claimed = snapshot != null && (snapshot['claimedDailyBonus'] == true || snapshot['dailyPointsEarned'] >= maxDailyPoints); // Also check dailyPointsEarned for robustness
      setClaimedToday(claimed);

      if (kDebugMode) {
        debugPrint('📦 Daily bonus claim check: $claimed (from DB)');
      }
    } catch (e, stack) {
      debugPrint('❌ Error checking daily bonus claim: $e\n$stack');
    }

    _lastClaimCheckedDate = date;
    await prefs.setString('lastClaimCheckedDate', date);
  }

  // --- Step Counting Logic (for actual Pedometer sensor) ---

  void _handleStepCount(int cumulativeStepsFromSensor) async {
    _rawSensorSteps = cumulativeStepsFromSensor;
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();
    final lastDate = prefs.getString('lastResetDate') ?? '';

    debugPrint('👣 [Sensor] Incoming: $cumulativeStepsFromSensor. Last Reset Date: $lastDate. Today: $today');

    // New day logic
    if (today != lastDate) {
      debugPrint('🔄 [Sensor] Detected new day. Applying new day logic.');
      _isNewDay = true;

      _dailySteps = 0;
      _dailyStepBaseline = cumulativeStepsFromSensor;
      await prefs.setInt('dailySteps', 0);
      await prefs.setInt('dailyStepBaseline', _dailyStepBaseline);
      await prefs.setString('lastResetDate', today);
      await prefs.remove('lastRecordedRawSensorSteps');

      // ✅ Use local credited flag first; DB fallback
      final yesterday = _yesterdayStr();
      final creditedFor = prefs.getString(_kStreakCreditedFor);
      final metYesterdayLocally = (creditedFor == yesterday);
      bool metYesterday = metYesterdayLocally;

      if (!metYesterdayLocally) {
        int yesterdaySteps = 0;
        try {
          final yDoc = await _databaseService.getDailyStatsOnce(yesterday);
          if (yDoc != null) {
            final s = yDoc['steps'];
            if (s is int) {
              yesterdaySteps = s;
            } else if (s is double) {
              yesterdaySteps = s.toInt();
            }
          }
        } catch (_) {}
        metYesterday = yesterdaySteps >= streakStepTarget;
      }

      if (!metYesterday) {
        _currentStreak = 0;
        await _databaseService.setUserProfileStreak(_currentStreak);
        await prefs.setInt('currentStreak', _currentStreak);
        // Mirror to today's dailyStats so UI reads fresh value too
        await _persistTodayStats(date: today, prefs: prefs);
        debugPrint('❌ Yesterday missed → streak reset to 0');
      } else {
        _currentStreak = await _databaseService.getUserProfileStreak();
        if (_currentStreak == 0) {
          _currentStreak = prefs.getInt('currentStreak') ?? 0;
        }
        await prefs.setInt('currentStreak', _currentStreak);
        debugPrint('✅ Yesterday met → keep streak at $_currentStreak');
      }

      await prefs.remove(_kStreakCreditedFor); // allow today's 10k credit
      setClaimedToday(false);
      await _checkIfClaimedToday(today);
    } else {
      // Same-day baseline inference if needed
      if (_dailyStepBaseline == 0 && cumulativeStepsFromSensor > 0) {
        final lastSavedDailySteps = prefs.getInt('dailySteps') ?? 0;
        final lastRecordedRawSensorSteps = prefs.getInt('lastRecordedRawSensorSteps') ?? 0;

        if (lastRecordedRawSensorSteps > 0 && cumulativeStepsFromSensor >= lastRecordedRawSensorSteps) {
          _dailyStepBaseline = lastRecordedRawSensorSteps - lastSavedDailySteps;
          debugPrint('🎯 [Sensor] Inferred _dailyStepBaseline: $_dailyStepBaseline (from prefs data)');
        } else {
          _dailyStepBaseline = cumulativeStepsFromSensor - lastSavedDailySteps;
          debugPrint('⚠️ [Sensor] Fallback: Inferred _dailyStepBaseline: $_dailyStepBaseline (from current sensor and stored daily)');
        }
        await prefs.setInt('dailyStepBaseline', _dailyStepBaseline);
      } else if (_dailyStepBaseline == 0) {
        _dailyStepBaseline = cumulativeStepsFromSensor;
        await prefs.setInt('dailyStepBaseline', _dailyStepBaseline);
        debugPrint('🔄 [Sensor] Reset baseline to incoming sensor ($cumulativeStepsFromSensor) as it was 0.');
      }

      _currentStreak = prefs.getInt('currentStreak') ?? _currentStreak;
    }

    final int calculatedDailySteps = (cumulativeStepsFromSensor - _dailyStepBaseline).clamp(0, 10000000);

    if (calculatedDailySteps > _dailySteps) {
      debugPrint('✨ [Sensor] New steps detected: $calculatedDailySteps > $_dailySteps');

      final oldPointsEarned = (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);
      _dailySteps = calculatedDailySteps; // update before recalculating
      final newPointsEarned = (_dailySteps ~/ stepsPerPoint).clamp(0, maxDailyPoints);

      final newPointsFromSteps = newPointsEarned - oldPointsEarned;
      if (newPointsFromSteps > 0) {
        _totalPoints += newPointsFromSteps;
        await prefs.setInt('totalPoints', _totalPoints);
        debugPrint('💰 Added $newPointsFromSteps new points from steps. Total: $_totalPoints');
      }

      await prefs.setInt('dailySteps', _dailySteps);
      await prefs.setInt('lastRecordedRawSensorSteps', cumulativeStepsFromSensor);
      _safeNotifyListeners();

      // 🔥 Immediate streak credit when today reaches target (once per day)
      debugPrint('🎯 Immediate streak check: steps=$_dailySteps, target=$streakStepTarget, creditedFor=${prefs.getString(_kStreakCreditedFor)}');
      if (_dailySteps >= streakStepTarget) {
        final creditedForToday = prefs.getString(_kStreakCreditedFor);
        if (creditedForToday != today) {
          _currentStreak = _currentStreak + 1; // increment for today
          await prefs.setInt('currentStreak', _currentStreak);
          await prefs.setString(_kStreakCreditedFor, today);

          await _databaseService.setUserProfileStreak(_currentStreak);
          await _persistTodayStats(date: today, prefs: prefs); // ✅ mirror to dailyStats

          _safeNotifyListeners();
          debugPrint('🔥 Daily streak credited immediately for $today → streak = $_currentStreak');
        }
      }
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

      // Only sync if daily steps, total points, or claim status have changed since last successful sync
      if (_dailySteps != lastSyncedSteps || _totalPoints != lastSyncedPoints || _hasClaimedToday != lastSyncedClaimStatus) {
        _status = StepStatus.syncing;
        _safeNotifyListeners();
        debugPrint('🔄 Initiating background sync: Daily Steps: $_dailySteps, Total Points: $_totalPoints, Claimed Today: $_hasClaimedToday');
        try {
          // saveStatsAndPoints now focuses on daily stats, totalPoints is updated in main user profile by other methods.
          await _databaseService.saveStatsAndPoints(
            date: today,
            steps: _dailySteps,
            dailyPointsEarned: dailyPointsEarned,
            streak: _currentStreak,
            // totalPoints: _totalPoints, // Removed from dailyStats save
            claimedDailyBonus: _hasClaimedToday, // Include the daily bonus claim status
          );
          lastSyncedSteps = _dailySteps;
          lastSyncedPoints = _totalPoints; // Still track for sync check, even if not saved directly here
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

    // Check if already claimed for today OR if max daily points from steps not yet earned
    if (_hasClaimedToday) {
      debugPrint('🚫 Claim rejected. Already claimed for today.');
      return;
    }
    if (dailyPointsEarned < maxDailyPoints) {
      debugPrint('🚫 Claim rejected. Not enough steps (${_dailySteps}) to earn max daily points (${maxDailyPoints}).');
      return;
    }

    try {
      // Atomically update totalPoints in the main user profile and dailyStats document.
      // DatabaseService().claimDailyPoints() already handles the transaction.
      await _databaseService.claimDailyPoints(); // This updates totalPoints in user profile and sets claimedDailyBonus in dailyStats

      // Update local state and SharedPreferences
      await loadTotalPointsFromDB(); // Reload total points from DB to ensure local state matches
      setClaimedToday(true); // Update local _hasClaimedToday flag

      debugPrint('✅ Claimed daily bonus. New total points: $_totalPoints');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to claim bonus: $e');
      debugPrint('Stack Trace: $stackTrace');
      // Revert local changes if transaction failed (totalPoints will be reloaded by `loadTotalPointsFromDB` on next refresh)
      setClaimedToday(false); // Revert local _hasClaimedToday if claim failed
      // No need to revert _totalPoints here as loadTotalPointsFromDB would fetch original if DB op failed.
    } finally {
      _safeNotifyListeners();
    }
  }


  // --- Point Redemption Logic (for spending accumulated points) ---
  // MODIFIED: `redeemPoints` now accepts `pointsToRedeem` as an argument.
  Future<int> redeemPoints(int pointsToRedeem) async { // <--- MODIFIED SIGNATURE
    if (_totalPoints < pointsToRedeem) {
      debugPrint('🚫 Cannot redeem points: Insufficient points. Total: $_totalPoints, Needed: $pointsToRedeem');
      return 0;
    }

    // You might also want a daily redemption cap here, if dailyRedemptionCap applies per transaction
    // Or if it applies to a sum of all redemptions in a day, you'd need to track _pointsRedeemedToday
    // related to this `pointsToRedeem` value, not `dailyRedemptionCap`.
    // For now, let's assume `dailyRedemptionCap` is a general guide, or needs re-evaluation.
    // If you always redeem a fixed amount, your original logic for dailyRedemptionCap makes sense.
    // If you redeem variable amounts (e.g. reward.pointsCost), then pointsRedeemedToday logic
    // needs to track sum of actual points redeemed.
    /*
    if (_pointsRedeemedToday + pointsToRedeem > dailyRedemptionCap) {
        debugPrint('🚫 Daily redemption cap reached. Attempted: ${pointsToRedeem}, Already Redeemed: ${_pointsRedeemedToday}, Cap: ${dailyRedemptionCap}');
        return 0;
    }
    */

    try {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());

      // Attempt to update totalPoints in Firestore via transaction
      final success = await _databaseService.redeemDailyPoints(
        date: date,
        pointsToRedeem: pointsToRedeem,
        currentTotalPoints: _totalPoints - pointsToRedeem, // Pass the NEW total *after* local deduction
      );

      if (success) {
        // Update local state after successful database operation
        _totalPoints -= pointsToRedeem;
        _pointsRedeemedToday += pointsToRedeem; // Track for daily cap if needed

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('totalPoints', _totalPoints); // Update local cache

        debugPrint('✅ Points redeemed successfully. Total points: $_totalPoints');
        return pointsToRedeem;
      } else {
        debugPrint('❌ Redemption failed to sync to database.');
        return 0; // Indicate failure
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
    _pointsRedeemedToday = 0; // Reset daily redemption status too

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dailySteps', 0);
    await prefs.setInt('dailyStepBaseline', 0);
    await prefs.remove('lastRecordedRawSensorSteps');

    setClaimedToday(false); // Clear claimed status for daily bonus
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
          prefs.setInt('totalPoints', _totalPoints);
        });
        debugPrint('💰 [Mock] Gained ${newPointsEarned - oldPointsEarned} points. Total points: $_totalPoints');
      }

      await SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('dailySteps', _dailySteps);
      });

      _safeNotifyListeners();

      // 🔥 Also credit streak in debug when crossing 10k (mirror _handleStepCount)
      final prefs2 = await SharedPreferences.getInstance();
      final today2 = _todayStr();
      final creditedFor2 = prefs2.getString(_kStreakCreditedFor);

      if (_dailySteps >= streakStepTarget && creditedFor2 != today2) {
        _currentStreak = _currentStreak + 1;
        await prefs2.setInt('currentStreak', _currentStreak);
        await prefs2.setString(_kStreakCreditedFor, today2);

        await _databaseService.setUserProfileStreak(_currentStreak);
        await _persistTodayStats(date: today2, prefs: prefs2); // ✅ mirror dailyStats

        _safeNotifyListeners();
        debugPrint('🔥 [Mock] Daily streak credited immediately for $today2 → streak = $_currentStreak');
      }

      // Immediately sync mock steps to database for visual verification in Firestore
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
      try {
        // saveStatsAndPoints now only manages daily stats, not totalPoints directly.
        await _databaseService.saveStatsAndPoints(
          date: today,
          steps: _dailySteps,
          dailyPointsEarned: dailyPointsEarned,
          streak: _currentStreak,
          // totalPoints: _totalPoints, // Removed from dailyStats save
          claimedDailyBonus: _hasClaimedToday, // Ensure this is also synced
        );

        // Explicitly update totalPoints in the main user profile if it changed
        // This is important because saveStatsAndPoints no longer does it.
        // It should happen whenever _totalPoints changes due to earning.
        // For simplicity, we are assuming it's done via claimDailyBonusPoints or _init.
        // If mock steps can directly affect totalPoints outside of a "claim" flow,
        // you might need a dedicated DB call here to update the user's totalPoints.
        // For now, relying on the periodic sync to propagate totalPoints changes.

        debugPrint('✅ [Mock] Steps synced to database for verification.');
      } catch (e, stackTrace) {
        debugPrint('❌ [Mock] Failed to sync mock steps to database: $e');
        debugPrint('Stack Trace: $stackTrace');
      }
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
      await prefs.setInt('dailySteps', 0);
      await prefs.setInt('dailyStepBaseline', 0);

      setClaimedToday(false); // Reset claim status for debug

      // Sync daily stats reset to Firestore
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
      try {
        await _databaseService.saveStatsAndPoints(
          date: today,
          steps: _dailySteps,
          dailyPointsEarned: dailyPointsEarned,
          streak: _currentStreak,
          // totalPoints: _totalPoints, // Removed from dailyStats save
          claimedDailyBonus: false, // Also reset in Firestore
        );
        debugPrint('✅ [Mock] Step reset synced to database.');
      } catch (e, stackTrace) {
        debugPrint('❌ [Mock] Failed to sync reset: $e');
        debugPrint('Stack Trace: $stackTrace');
      }

      // If you want to reset _totalPoints in debug mode
      // _totalPoints = 0;
      // await _databaseService.updateTotalPointsInProfile(0); // You would need to add this method in DatabaseService
      // await prefs.setInt('totalPoints', _totalPoints);

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