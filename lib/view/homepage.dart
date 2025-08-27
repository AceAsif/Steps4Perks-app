import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/features/step_gauge.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/foundation.dart'; // Import kDebugMode
//import 'package:myapp/services/database_service.dart';

// This is the parent widget that manages the state and provides keys for the tutorial.
class HomePage extends StatefulWidget {
  // Use GlobalKey to identify widgets for the tutorial overlay.
  final GlobalKey stepGaugeKey;
  final GlobalKey dailyStreakKey;
  final GlobalKey pointsEarnedKey;
  final GlobalKey mockStepsKey;

  const HomePage({
    super.key,
    required this.stepGaugeKey,
    required this.dailyStreakKey,
    required this.pointsEarnedKey,
    required this.mockStepsKey,
  });

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _oldSteps = 0; // Used for TweenAnimationBuilder's 'begin' value
  bool _isLoading = true; // Controls shimmer visibility
  bool _hasLoadedData = false; // Prevents redundant initial data loads

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData(); // Trigger data loading after the first frame
    });
  }

  Future<void> _loadData() async {
    debugPrint("🔁 _loadData called");
    if (_hasLoadedData) {
      debugPrint("⏩ Skipping _loadData (already loaded)");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final stepTracker = Provider.of<StepTracker>(context, listen: false);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());

    try {
      final data = await stepTracker.getDailyStatsForUI(today);
      debugPrint(data != null ? "📦 Firestore data received" : "🚫 No data found for today");

      if (data != null) {
        debugPrint("👣 Steps: ${data['steps']}, 🔥 Streak: ${data['streak']}, 🎯 Daily Points: ${data['dailyPointsEarned']}");
        stepTracker.setCurrentSteps(data['steps'] ?? 0);
        final int streakFromDb = (data['streak'] as int?) ?? 0;
        // Prefer the larger of provider (live) and DB, so we don't clobber the immediate increment
        if (streakFromDb > stepTracker.currentStreak) {
          stepTracker.setCurrentStreak(streakFromDb);
        }
        // Ensure that hasClaimedToday reflects the 'claimedDailyBonus' field from Firestore
        // (You've updated database_service.dart to use 'claimedDailyBonus')
        stepTracker.setClaimedToday(data['claimedDailyBonus'] == true);
      } else {
        stepTracker.setCurrentSteps(0);
        stepTracker.setClaimedToday(false);
      }

      _hasLoadedData = true;
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error loading data: $e');
      debugPrint('Stack Trace: $stackTrace');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _oldSteps = stepTracker.currentSteps;
          debugPrint("✅ Data loading complete. isLoading = $_isLoading, _oldSteps = $_oldSteps");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomePageContent(
      stepGaugeKey: widget.stepGaugeKey,
      dailyStreakKey: widget.dailyStreakKey,
      pointsEarnedKey: widget.pointsEarnedKey,
      mockStepsKey: widget.mockStepsKey,
      oldSteps: _oldSteps,
      isLoading: _isLoading,
      loadData: _loadData,
      parentContext: context, // Pass the context here
    );
  }
}

// This widget is now the content part that only handles the UI.
class HomePageContent extends StatelessWidget {
  final GlobalKey stepGaugeKey;
  final GlobalKey dailyStreakKey;
  final GlobalKey pointsEarnedKey;
  final GlobalKey mockStepsKey;
  final int oldSteps;
  final bool isLoading;
  final Future<void> Function() loadData;
  final BuildContext parentContext; // Receive the context here

  const HomePageContent({
    super.key,
    required this.stepGaugeKey,
    required this.dailyStreakKey,
    required this.pointsEarnedKey,
    required this.mockStepsKey,
    required this.oldSteps,
    required this.isLoading,
    required this.loadData,
    required this.parentContext, // And here
  });

  @override
  Widget build(BuildContext context) {
    final stepTracker = Provider.of<StepTracker>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await loadData();
        },
        child: isLoading
            ? _buildShimmer(screenHeight)
            : SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: screenHeight * 0.001,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              if (kDebugMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🧪 Debug Mode Active',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // Use the provided GlobalKey
              _buildGauge(screenWidth, stepTracker, stepGaugeKey),
              _buildSummaryCards(stepTracker, dailyStreakKey, pointsEarnedKey),
              const SizedBox(height: 20),
              // Pass the context here
              _buildClaimButton(stepTracker, screenWidth, parentContext),
              const SizedBox(height: 20),
              if (kDebugMode)
                _buildEmulatorControls(context, mockStepsKey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer(double screenHeight) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Column(
            children: List.generate(
              3,
                  (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Refactored to accept key
  Widget _buildGauge(double screenWidth, StepTracker tracker, GlobalKey key) {
    return SizedBox(
      key: key, // Assign the key here
      width: screenWidth * 0.65,
      height: screenWidth * 0.65,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: oldSteps.toDouble(),
          end: tracker.currentSteps.toDouble(),
        ),
        duration: const Duration(milliseconds: 600),
        builder: (context, value, child) =>
            StepGauge(currentSteps: value.toInt()),
      ),
    );
  }

  // Refactored to accept keys
  Widget _buildSummaryCards(StepTracker tracker, GlobalKey dailyKey, GlobalKey pointsKey) {
    return Row(
      children: [
        Expanded(
          child: _buildCard(
              Icons.local_fire_department, 'Daily Streak', '${tracker.currentStreak}', dailyKey),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCard(Icons.monetization_on, 'Points Earned',
              '${tracker.dailyPointsEarned} / ${StepTracker.maxDailyPoints}', pointsKey),
        ),
      ],
    );
  }

  // Refactored to accept key
  Widget _buildCard(IconData icon, String label, String value, GlobalKey key) {
    return Card(
      key: key, // Assign the key here
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.deepOrange),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // Refactored _buildClaimButton to accept context as a parameter
  Widget _buildClaimButton(StepTracker tracker, double width, BuildContext context) {
    final bool canClaim = tracker.dailyPointsEarned >= StepTracker.maxDailyPoints &&
        !tracker.hasClaimedToday;

    return SizedBox(
      width: width * 0.75,
      child: ElevatedButton(
        onPressed: canClaim
            ? () async {
          await tracker.claimDailyBonusPoints();
          if (!context.mounted) return;
          if (tracker.hasClaimedToday) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('🎉 Claimed ${StepTracker.maxDailyPoints} Daily Points!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('😞 Failed to claim daily bonus points. Try again.')),
            );
          }
        }
            : null, // Disable the button
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.redeem, size: 24),
            const SizedBox(width: 8),
            Text(
              tracker.hasClaimedToday
                  ? '✅ ${StepTracker.maxDailyPoints} Points Claimed Today'
                  : 'Claim ${StepTracker.maxDailyPoints} Points (Daily)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // Refactored to accept key
  Widget _buildEmulatorControls(BuildContext context, GlobalKey key) {
    final stepTracker = Provider.of<StepTracker>(context, listen: false);
    return Column(
      children: [
        const SizedBox(height: 10),
        ElevatedButton(
          key: key, // Assign the key here
          onPressed: () {
            stepTracker.addMockSteps(1000);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Added 1000 mock steps!')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('➕ Add 1000 Mock Steps (Debug Only)'),
        ),
        ElevatedButton(
          onPressed: () {
            stepTracker.resetMockSteps();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reset mock steps to 0!')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Reset mock steps to 0!'),
        ),
      ],
    );
  }
}
