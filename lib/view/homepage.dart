import 'package:flutter/material.dart';
import 'package:myapp/features/step_gauge.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/services/database_service.dart';

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

class HomePageState extends State<HomePage> {
  int _oldSteps = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// ✅ Load data when page is first created
  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _loadData(user.uid);
    }
  }

  /// ✅ Reload data from Firestore
  Future<void> _loadData(String userId) async {
    final stepTracker = Provider.of<StepTracker>(context, listen: false);

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final data = await DatabaseService().getDailyStatsOnce(userId);

      debugPrint(data != null ? '✅ Firestore data received' : '🚫 No data found for today');

      if (data != null) {
        debugPrint('📊 Steps: ${data['steps']}, Streak: ${data['streak']}, Daily Points: ${data['dailyPointsEarned']}');

        stepTracker.setCurrentSteps(data['steps'] ?? 0);

        final int streakFromDb = (data['streak'] as int?) ?? 0;
        if (streakFromDb != stepTracker.currentStreak) {
          stepTracker.setCurrentStreak(streakFromDb);
        }

        stepTracker.setClaimedToday(data['claimedDailyBonus'] == true);
      } else {
        stepTracker.setCurrentSteps(0);
        stepTracker.setClaimedToday(false);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _oldSteps = stepTracker.currentSteps;
        });
      }

      debugPrint('✅ Data loading complete. isLoading = $_isLoading, _oldSteps = $_oldSteps');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading data: $e');
      debugPrint('Stack Trace: $stackTrace');

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// ✅ Public method to refresh data (called from BottomNavigation)
  Future<void> refreshData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _loadData(user.uid);
    }
  }

  /// ✅ Refresh handler for pull-to-refresh
  Future<void> _handleRefresh() async {
    await refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          return HomePageContent(
            stepGaugeKey: widget.stepGaugeKey,
            dailyStreakKey: widget.dailyStreakKey,
            pointsEarnedKey: widget.pointsEarnedKey,
            mockStepsKey: widget.mockStepsKey,
            oldSteps: _oldSteps,
            isLoading: _isLoading,
            onRefresh: _handleRefresh,
            parentContext: context,
          );
        } else {
          return const Center(child: Text('Please sign in.'));
        }
      },
    );
  }
}

/// This widget handles the UI only - NO CustomTopBar or Scaffold here
class HomePageContent extends StatelessWidget {
  final GlobalKey stepGaugeKey;
  final GlobalKey dailyStreakKey;
  final GlobalKey pointsEarnedKey;
  final GlobalKey mockStepsKey;
  final int oldSteps;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final BuildContext parentContext;

  const HomePageContent({
    super.key,
    required this.stepGaugeKey,
    required this.dailyStreakKey,
    required this.pointsEarnedKey,
    required this.mockStepsKey,
    required this.oldSteps,
    required this.isLoading,
    required this.onRefresh,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    final stepTracker = Provider.of<StepTracker>(context);
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
              _buildGauge(screenWidth, stepTracker, stepGaugeKey),
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

  Widget _buildGauge(double screenWidth, StepTracker tracker, GlobalKey key) {
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
