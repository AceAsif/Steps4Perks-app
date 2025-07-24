import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/features/step_gauge.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/foundation.dart'; // Import kDebugMode
import 'package:myapp/services/database_service.dart';

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  HomePageContentState createState() => HomePageContentState();
}

class HomePageContentState extends State<HomePageContent> {
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
        stepTracker.setCurrentStreak(data['streak'] ?? 0);
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
    final stepTracker = Provider.of<StepTracker>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          _hasLoadedData = false;
          setState(() => _isLoading = true);
          await _loadData();
        },
        child: _isLoading
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
              _buildGauge(screenWidth, stepTracker),
              _buildSummaryCards(stepTracker),
              const SizedBox(height: 20),
              // Use the refactored _buildClaimButton
              _buildClaimButton(stepTracker, screenWidth),
              const SizedBox(height: 20),
              if (kDebugMode)
                _buildEmulatorControls(context),
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

  Widget _buildGauge(double screenWidth, StepTracker tracker) {
    return SizedBox(
      width: screenWidth * 0.65,
      height: screenWidth * 0.65,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: _oldSteps.toDouble(),
          end: tracker.currentSteps.toDouble(),
        ),
        duration: const Duration(milliseconds: 600),
        builder: (context, value, child) =>
            StepGauge(currentSteps: value.toInt()),
        onEnd: () => _oldSteps = tracker.currentSteps,
      ),
    );
  }

  Widget _buildSummaryCards(StepTracker tracker) {
    return Row(
      children: [
        Expanded(
          child: _buildCard(
              Icons.local_fire_department, 'Daily Streak', '${tracker.currentStreak}'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCard(Icons.monetization_on, 'Points Earned',
              '${tracker.dailyPointsEarned} / ${StepTracker.maxDailyPoints}'),
        ),
      ],
    );
  }

  Widget _buildCard(IconData icon, String label, String value) {
    return Card(
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

  // Refactored _buildClaimButton to call claimDailyBonusPoints
  Widget _buildClaimButton(StepTracker tracker, double width) {
    // Condition for enabling the button:
    // 1. Daily points earned must be at or above maxDailyPoints (100)
    // 2. The daily bonus must NOT have been claimed today
    final bool canClaim = tracker.dailyPointsEarned >= StepTracker.maxDailyPoints &&
        !tracker.hasClaimedToday;

    return SizedBox(
      width: width * 0.75,
      child: ElevatedButton(
        onPressed: canClaim
            ? () async {
          await tracker.claimDailyBonusPoints();
          if (!mounted) return; // Check if the widget is still mounted
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

  Widget _buildEmulatorControls(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            // commen out to set reset
            // Provider.of<StepTracker>(context, listen: false).resetMockSteps();
            Provider.of<StepTracker>(context, listen: false)
                .addMockSteps(1000);
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
            Provider.of<StepTracker>(context, listen: false).resetMockSteps();
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
          child: const Text('Reset mock steps to 0!'), // Clarified text
        ),
      ],
    );
  }
}