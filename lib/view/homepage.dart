import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/features/step_gauge.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/foundation.dart'; // Import kDebugMode

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
        // Ensure _isLoading is false if already loaded and we're skipping
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    // Get StepTracker instance without listening to avoid unnecessary rebuilds during data loading
    final stepTracker = Provider.of<StepTracker>(context, listen: false);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());

    try {
      final data = await stepTracker.getDailyStatsForUI(today);
      debugPrint(data != null ? "📦 Firestore data received" : "🚫 No data found for today");

      if (data != null) {
        debugPrint("👣 Steps: ${data['steps']}, 🔥 Streak: ${data['streak']}, 🎯 Daily Points: ${data['dailyPointsEarned']}");
        stepTracker.setCurrentSteps(data['steps'] ?? 0);
        stepTracker.setCurrentStreak(data['streak'] ?? 0);
        // Do NOT set _totalPoints here. _totalPoints is overall and loaded in _loadPoints()
        // stepTracker.setTotalPoints(data['dailyPointsEarned'] ?? 0); // REMOVE THIS LINE
        stepTracker.setClaimedToday(data['redeemed'] == true);
      } else {
        // If no data for today, initialize daily relevant UI state to zero/false
        stepTracker.setCurrentSteps(0);
        stepTracker.setClaimedToday(false);
        // Streak and total points (overall) are loaded by StepTracker's _loadBaseline and _loadPoints,
        // so no need to set them to 0 here for a fresh day's record.
      }

      _hasLoadedData = true; // Mark as loaded only after successful data processing
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error loading data: $e');
      debugPrint('Stack Trace: $stackTrace');
    } finally {
      // Always ensure loading state is false when operation completes, regardless of success/failure
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Set _oldSteps here to ensure animation starts from current displayed steps
          _oldSteps = stepTracker.currentSteps;
          debugPrint("✅ Data loading complete. isLoading = $_isLoading, _oldSteps = $_oldSteps");
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Listen to StepTracker for UI updates
    final stepTracker = Provider.of<StepTracker>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          // Reset _hasLoadedData to false to force a full reload from DB
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
          physics: const AlwaysScrollableScrollPhysics(), // Allows pull-to-refresh even with short content
          child: Column(
            children: [
              // Display debug/emulator mode banner only in debug builds
              if (kDebugMode) // Use kDebugMode
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🧪 Debug Mode Active', // Clarified text
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
              _buildClaimButton(stepTracker, screenWidth),
              const SizedBox(height: 20),
              // Display emulator controls only in debug builds
              if (kDebugMode) // Use kDebugMode
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

  Widget _buildClaimButton(StepTracker tracker, double width) {
    return SizedBox(
      width: width * 0.75,
      child: ElevatedButton(
        onPressed: tracker.dailyPointsEarned >= StepTracker.maxDailyPoints &&
            !tracker.hasClaimedToday
            ? () async {
          final successAmount = await tracker.redeemPoints(); // redeemPoints returns int (amount redeemed)
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  successAmount > 0 // Check if more than 0 points were redeemed
                      ? '🎉 Claimed $successAmount Daily Points!'
                      : '⚠️ Already claimed or error occurred'),
            ),
          );
        }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.redeem, size: 24),
            const SizedBox(width: 8),
            Text(
              tracker.hasClaimedToday
                  ? '✅ 100 Points Claimed Today'
                  : 'Claim 100 Points (Daily)',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmulatorControls(BuildContext context) {
    return Column(
      children: [
        // Text is now managed by the main build method for consistency
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
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
          child: const Text('➕ Add 1000 Mock Steps (Debug Only)'), // Clarified text
        ),
      ],
    );
  }
}