import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/features/step_gauge.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:provider/provider.dart';

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  HomePageContentState createState() => HomePageContentState();
}

class HomePageContentState extends State<HomePageContent> {
  int _oldSteps = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stepTracker = Provider.of<StepTracker>(context, listen: false);
    if (mounted) {
      _oldSteps = stepTracker.currentSteps;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepTracker = Provider.of<StepTracker>(context);
    final currentSteps = stepTracker.currentSteps;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final bodyTextColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: screenHeight * 0.001,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            _buildGauge(
              screenWidth,
              screenHeight,
              currentSteps,
              bodyTextColor,
              subtitleColor,
            ),
            _buildSummaryCards(stepTracker, bodyTextColor, subtitleColor),
            SizedBox(height: screenHeight * 0.03),

            // --- Daily Claim Button (100 Points) ---
            SizedBox(
              width: screenWidth * 0.75,
              child: ElevatedButton(
                onPressed: stepTracker.dailyPoints >= StepTracker.maxDailyPoints &&
                        !stepTracker.hasClaimedToday
                    ? () async {
                        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                        final success = await stepTracker.claimDailyPoints(today);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? '🎉 Claimed 100 Daily Points!'
                                  : '⚠️ Already claimed or error occurred'),
                            ),
                          );
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  elevation: 5,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.redeem, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      stepTracker.hasClaimedToday
                          ? '✅ 100 Points Claimed Today'
                          : 'Claim 100 Points (Daily)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: screenHeight * 0.03),

            // --- Emulator Mode Controls ---
            if (!stepTracker.isPhysicalDevice) ...[
              const Padding(
                padding: EdgeInsets.only(top: 20.0),
                child: Text(
                  '🧪 Emulator Mode Active!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: ElevatedButton(
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 20,
                    ),
                  ),
                  child: const Text('➕ Add 1000 Mock Steps (Emulator Only)'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGauge(
    double screenWidth,
    double screenHeight,
    int currentSteps,
    Color bodyTextColor,
    Color subtitleColor,
  ) {
    return SizedBox(
      width: screenWidth * 0.65,
      height: screenWidth * 0.65,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: _oldSteps.toDouble(),
          end: currentSteps.toDouble(),
        ),
        duration: const Duration(milliseconds: 600),
        builder: (context, value, child) {
          return StepGauge(currentSteps: value.toInt());
        },
        onEnd: () {
          _oldSteps = currentSteps;
        },
      ),
    );
  }

  Widget _buildSummaryCards(
    StepTracker stepTracker,
    Color bodyTextColor,
    Color subtitleColor,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildCard(
            context: context,
            icon: Icons.local_fire_department,
            label: 'Daily Streak',
            value: '${stepTracker.currentStreak}',
            bodyTextColor: bodyTextColor,
            subtitleColor: subtitleColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCard(
            context: context,
            icon: Icons.monetization_on,
            label: 'Points Earned',
            value: '${stepTracker.dailyPoints} / ${StepTracker.maxDailyPoints}',
            bodyTextColor: bodyTextColor,
            subtitleColor: subtitleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color bodyTextColor,
    required Color subtitleColor,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        width: screenWidth * 0.4,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: screenWidth * 0.08, color: Colors.deepOrange),
            SizedBox(height: screenWidth * 0.02),
            Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                color: subtitleColor,
              ),
            ),
            SizedBox(height: screenWidth * 0.01),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: bodyTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
