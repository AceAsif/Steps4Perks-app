import 'package:flutter/material.dart';
import 'package:myapp/features/step_gauge.dart'; // Assuming StepGauge is a separate widget for the circular progress
import 'package:myapp/features/step_tracker.dart';
import 'package:provider/provider.dart';

// No direct DatabaseService, FirebaseAuth, or CloudFirestore imports needed here,
// as StepTracker handles them internally.

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  HomePageContentState createState() => HomePageContentState();
}

class HomePageContentState extends State<HomePageContent> {
  // _oldSteps is used for the TweenAnimationBuilder to animate step changes
  int _oldSteps = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This is called when dependencies change (like Provider updates).
    // We update _oldSteps here to ensure the animation starts from the previous value
    // when currentSteps changes.
    final stepTracker = Provider.of<StepTracker>(context, listen: false);
    // Only update _oldSteps if the widget is mounted to prevent errors during dispose
    if (mounted) {
      _oldSteps = stepTracker.currentSteps;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to StepTracker for real-time updates to currentSteps, totalPoints, and currentStreak
    final stepTracker = Provider.of<StepTracker>(context);
    final currentSteps = stepTracker.currentSteps;
    final totalPoints = stepTracker.totalPoints; // Get total points from StepTracker
    final currentStreak = stepTracker.currentStreak; // Get current streak from StepTracker

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Determine text colors based on theme (assuming light theme defaults to dark text)
    final bodyTextColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: screenHeight * 0.001,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- Step Gauge (Circular Progress) ---
            _buildGauge(screenWidth, screenHeight, currentSteps, bodyTextColor, subtitleColor),

            // --- Summary Cards (Daily Streak, Points Earned) ---
            _buildSummaryCards(stepTracker, bodyTextColor, subtitleColor), // Pass stepTracker and colors

            SizedBox(height: screenHeight * 0.03),

            // --- Redeem Points Button ---
            _buildRedeemButton(screenWidth, stepTracker), // Pass stepTracker to the button builder

            SizedBox(height: screenHeight * 0.03),

            // --- Mock Steps Button (for emulator testing) ---
            // Only show if pedometer is not available (e.g., on emulator)
            if (!stepTracker.isPedometerAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: ElevatedButton(
                  onPressed: () {
                    // Add 1000 mock steps
                    Provider.of<StepTracker>(context, listen: false).addMockSteps(1000);
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
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  ),
                  child: const Text('➕ Add 1000 Mock Steps (Emulator Only)'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the circular step gauge with animation.
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
          begin: _oldSteps.toDouble(), // Animation starts from old steps
          end: currentSteps.toDouble(), // Animates to current steps
        ),
        duration: const Duration(milliseconds: 600), // Animation duration
        builder: (context, value, child) {
          // StepGauge widget displays the animated step count
          return StepGauge(currentSteps: value.toInt()); // StepGauge needs to be updated to use int
        },
        onEnd: () {
          // Update _oldSteps to currentSteps after animation ends for the next animation cycle
          _oldSteps = currentSteps;
        },
      ),
    );
  }

  /// Builds the row of summary cards (Daily Streak, Points Earned).
  Widget _buildSummaryCards(StepTracker stepTracker, Color bodyTextColor, Color subtitleColor) {
    return Row(
      children: [
        Expanded(
          child: _buildCard(
            context, // Pass context to _buildCard
            icon: Icons.local_fire_department,
            label: 'Daily Streak',
            value: '${stepTracker.currentStreak}', // Display the current streak
            showFireIcon: true,
            bodyTextColor: bodyTextColor,
            subtitleColor: subtitleColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCard(
            context, // Pass context to _buildCard
            icon: Icons.monetization_on,
            label: 'Points Earned',
            value: '${stepTracker.dailyPoints} / ${StepTracker.maxDailyPoints}', // Display daily points
            showFireIcon: false,
            bodyTextColor: bodyTextColor,
            subtitleColor: subtitleColor,
          ),
        ),
      ],
    );
  }

  /// Helper method to build individual info cards.
  Widget _buildCard(
    BuildContext context, { // Added context parameter
    required IconData icon,
    required String label,
    required String value,
    bool showFireIcon = false,
    required Color bodyTextColor, // Added for explicit color control
    required Color subtitleColor, // Added for explicit color control
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text.rich(
            TextSpan(
              children: [
                if (showFireIcon)
                  const TextSpan(
                    text: '🔥 ',
                    style: TextStyle(fontSize: 20),
                  ),
                TextSpan(
                  text: label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor, // Use subtitle color for label
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: bodyTextColor, // Use body color for value
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the "Redeem Points" button.
  Widget _buildRedeemButton(double screenWidth, StepTracker stepTracker) {
    return SizedBox(
      width: screenWidth * 0.75,
      child: ElevatedButton(
        onPressed: stepTracker.canRedeemGiftCard // Button is enabled only if user can redeem
            ? () {
                // TODO: Implement actual redeem logic (e.g., show ad, then redeem)
                stepTracker.redeemGiftCard(); // Call redeemGiftCard from StepTracker
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Points Redeemed!')),
                );
              }
            : null, // Button is disabled if canRedeemGiftCard is false
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.card_giftcard, size: 24), // Gift icon
            const SizedBox(width: 8),
            Text(
              'Redeem Points (${stepTracker.totalPoints} / ${StepTracker.giftCardThreshold})', // Display current total points
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
