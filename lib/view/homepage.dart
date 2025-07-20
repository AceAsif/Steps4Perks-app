import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/features/step_gauge.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  HomePageContentState createState() => HomePageContentState();
}

class HomePageContentState extends State<HomePageContent> {
  int _oldSteps = 0;
  bool _isLoading = true;

  Future<void> _loadData() async {
    final stepTracker = Provider.of<StepTracker>(context, listen: false);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final data = await stepTracker.databaseService.getDailyStatsStream(today).first.timeout(const Duration(seconds: 5));
      if (data != null) {
        stepTracker.setCurrentSteps(data['steps'] ?? 0);
        stepTracker.setCurrentStreak(data['streak'] ?? 0);
        stepTracker.setTotalPoints(data['totalPoints'] ?? 0);
        stepTracker.setClaimedToday(data['redeemed'] == true);
      }
    } catch (e) {
      debugPrint('⚠️ Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
    _oldSteps = Provider.of<StepTracker>(context, listen: false).currentSteps;
  }

  @override
  Widget build(BuildContext context) {
    final stepTracker = Provider.of<StepTracker>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isLoading = true);
          await _loadData();
        },
        child: _isLoading
            ? _buildShimmer(screenHeight)
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.001),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    if (!stepTracker.isPhysicalDevice)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '🧪 Emulator Mode Active',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                        ),
                      ),
                    _buildGauge(screenWidth, stepTracker),
                    _buildSummaryCards(stepTracker),
                    const SizedBox(height: 20),
                    _buildClaimButton(stepTracker, screenWidth),
                    const SizedBox(height: 20),
                    if (!stepTracker.isPhysicalDevice) _buildEmulatorControls(context),
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
        )
      ],
    );
  }

  Widget _buildGauge(double screenWidth, StepTracker tracker) {
    return SizedBox(
      width: screenWidth * 0.65,
      height: screenWidth * 0.65,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: _oldSteps.toDouble(), end: tracker.currentSteps.toDouble()),
        duration: const Duration(milliseconds: 600),
        builder: (context, value, child) => StepGauge(currentSteps: value.toInt()),
        onEnd: () => _oldSteps = tracker.currentSteps,
      ),
    );
  }

  Widget _buildSummaryCards(StepTracker tracker) {
    return Row(
      children: [
        Expanded(
          child: _buildCard(Icons.local_fire_department, 'Daily Streak', '${tracker.currentStreak}'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCard(Icons.monetization_on, 'Points Earned', '${tracker.dailyPoints} / ${StepTracker.maxDailyPoints}'),
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
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimButton(StepTracker tracker, double width) {
    return SizedBox(
      width: width * 0.75,
      child: ElevatedButton(
        onPressed: tracker.dailyPoints >= StepTracker.maxDailyPoints && !tracker.hasClaimedToday
            ? () async {
                final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                final success = await tracker.claimDailyPoints(today);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? '🎉 Claimed 100 Daily Points!' : '⚠️ Already claimed or error occurred')),
                );
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
              tracker.hasClaimedToday ? '✅ 100 Points Claimed Today' : 'Claim 100 Points (Daily)',
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
        const Text('🧪 Emulator Mode Active!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            Provider.of<StepTracker>(context, listen: false).addMockSteps(1000);
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
          child: const Text('➕ Add 1000 Mock Steps (Emulator Only)'),
        ),
      ],
    );
  }
}