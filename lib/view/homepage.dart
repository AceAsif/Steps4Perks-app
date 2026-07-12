import 'package:flutter/material.dart';
import 'package:steps4perks/features/step_gauge.dart';
import 'package:steps4perks/features/step_tracker.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/foundation.dart';
// 🟢 REMOVED: No longer need FirebaseAuth or DatabaseService here
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:steps4perks/services/database_service.dart';

/// This is the parent widget that manages the state and provides keys for the tutorial.
class HomePage extends StatefulWidget {
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

class HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {

  // 🟢 REMOVED: All local state is gone (_oldSteps, _isLoading)
  // 🟢 REMOVED: All data loading logic is gone (initState, _loadInitialData, _loadData)

  @override
  bool get wantKeepAlive => true;

  /// ✅ Refresh handler for pull-to-refresh
  Future<void> _handleRefresh() async {
    // 🟢 CHANGED: We now call the provider's refresh method
    await Provider.of<StepTracker>(context, listen: false).refreshData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Keep this for AutomaticKeepAliveClientMixin

    // 🟢 REMOVED: The StreamBuilder<User?> is gone.
    // AuthGate already guarantees we have a user and are on this page.

    // We just return the HomePageContent directly.
    return HomePageContent(
      stepGaugeKey: widget.stepGaugeKey,
      dailyStreakKey: widget.dailyStreakKey,
      pointsEarnedKey: widget.pointsEarnedKey,
      mockStepsKey: widget.mockStepsKey,
      onRefresh: _handleRefresh,
      parentContext: context,
    );
  }
}

/// This widget handles the UI only - NO CustomTopBar or Scaffold here
class HomePageContent extends StatelessWidget {
  final GlobalKey stepGaugeKey;
  final GlobalKey dailyStreakKey;
  final GlobalKey pointsEarnedKey;
  final GlobalKey mockStepsKey;
  final Future<void> Function() onRefresh;
  final BuildContext parentContext;

  const HomePageContent({
    super.key,
    required this.stepGaugeKey,
    required this.dailyStreakKey,
    required this.pointsEarnedKey,
    required this.mockStepsKey,
    required this.onRefresh,
    required this.parentContext,
    // 🟢 REMOVED: oldSteps and isLoading are no longer passed in
  });

  @override
  Widget build(BuildContext context) {
    // 🟢 CHANGED: We now get isLoading and oldSteps directly from the provider
    final stepTracker = Provider.of<StepTracker>(context);
    final bool isLoading = stepTracker.isLoading;
    final int oldSteps = stepTracker.oldSteps;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // ✅ NO Scaffold or CustomTopBar - just return the content
    return SafeArea(
      bottom: false, // Allow floating bottom nav
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: isLoading
            ? _buildShimmer(screenHeight)
            : SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: screenHeight * 0.02,
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
                    'Debug Mode Active',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // 🟢 CHANGED: Pass 'oldSteps' to the gauge
              _buildGauge(screenWidth, stepTracker, stepGaugeKey, oldSteps),
              const SizedBox(height: 20),
              _buildSummaryCards(stepTracker, dailyStreakKey, pointsEarnedKey),
              const SizedBox(height: 20),
              _buildClaimButton(stepTracker, screenWidth, parentContext),
              const SizedBox(height: 20),
              if (kDebugMode) _buildEmulatorControls(context, mockStepsKey),
              const SizedBox(height: 100), // ✅ Extra space for floating nav bar
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

  // 🟢 CHANGED: Added 'oldSteps' parameter
  Widget _buildGauge(double screenWidth, StepTracker tracker, GlobalKey key, int oldSteps) {
    return SizedBox(
      key: key,
      width: screenWidth * 0.65,
      height: screenWidth * 0.65,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: oldSteps.toDouble(),
          end: tracker.currentSteps.toDouble(),
        ),
        duration: const Duration(milliseconds: 600),
        builder: (context, value, child) {
          // 🟢 NOTE: Your step_gauge.dart file is correct
          return StepGauge(currentSteps: value.toInt());
        },
      ),
    );
  }

  Widget _buildSummaryCards(
      StepTracker tracker, GlobalKey dailyKey, GlobalKey pointsKey) {
    return Row(
      children: [
        Expanded(
          child: _buildCard(
            Icons.local_fire_department,
            'Daily Streak',
            '${tracker.currentStreak}',
            dailyKey,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCard(
            Icons.monetization_on,
            'Points Earned',
            '${tracker.dailyPointsEarned}/${StepTracker.maxDailyPoints}',
            pointsKey,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(IconData icon, String label, String value, GlobalKey key) {
    return Card(
      key: key,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.deepOrange),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimButton(
      StepTracker tracker, double width, BuildContext context) {
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
              SnackBar(
                content:
                Text('✅ Claimed ${StepTracker.maxDailyPoints} Daily Points!'),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Failed to claim daily bonus points. Try again.'),
              ),
            );
          }
        }
            : null,
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
                  : 'Claim ${StepTracker.maxDailyPoints} Points Daily',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmulatorControls(BuildContext context, GlobalKey key) {
    final stepTracker = Provider.of<StepTracker>(context, listen: false);

    return Column(
      children: [
        const SizedBox(height: 10),
        ElevatedButton(
          key: key,
          onPressed: () {
            stepTracker.addMockSteps(1000);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Added 1000 mock steps!')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Add 1000 Mock Steps (Debug Only)'),
        ),
        const SizedBox(height: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Reset Mock Steps to 0!'),
        ),
      ],
    );
  }
}