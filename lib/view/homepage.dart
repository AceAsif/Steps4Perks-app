import 'package:flutter/material.dart';
import 'package:myapp/features/step_gauge.dart'; // Assuming StepGauge is a separate widget for the circular progress
import 'package:myapp/features/step_tracker.dart';
import 'package:provider/provider.dart';
import 'package:myapp/services/ad_service.dart'; // Import AdService (now the mocked one)

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  HomePageContentState createState() => HomePageContentState();
}

class HomePageContentState extends State<HomePageContent> {
  int _oldSteps = 0;
  final AdService _adService =
      AdService(); // Get instance of AdService (the mocked one)

  @override
  void initState() {
    super.initState();
    _adService
        .loadRewardedAd(); // Start loading a mock ad as soon as the page loads
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stepTracker = Provider.of<StepTracker>(context, listen: false);
    if (mounted) {
      _oldSteps = stepTracker.currentSteps;
    }
  }

  @override
  void dispose() {
    _adService.dispose(); // Dispose the mock ad when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stepTracker = Provider.of<StepTracker>(context);
    final currentSteps = stepTracker.currentSteps;
    final totalPoints = stepTracker.totalPoints;
    final currentStreak = stepTracker.currentStreak;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final bodyTextColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

    final bool canActivateRedeemButton =
        stepTracker.canRedeemPoints && _adService.isAdReady;
    final bool showAdLoadingIndicator =
        stepTracker.canRedeemPoints && !_adService.isAdReady;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: screenHeight * 0.001,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 🧪 Emulator Mode Badge
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

            // --- Redeem Points Button ---
            SizedBox(
              width: screenWidth * 0.75,
              child: ElevatedButton(
                onPressed:
                    canActivateRedeemButton
                        ? () async {
                          debugPrint(
                            'Redeem button pressed. Showing mock ad...',
                          );
                          final bool adWatchedSuccessfully =
                              await _adService.showRewardedAd(); // Call mock ad

                          if (!mounted) return; // Check mounted after async gap

                          if (adWatchedSuccessfully) {
                            debugPrint(
                              'Mock Ad watched successfully! Proceeding with redemption.',
                            );
                            final int redeemedAmount =
                                await stepTracker
                                    .redeemPoints(); // Call redeemPoints method
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Redeemed $redeemedAmount points after "watching" ad!',
                                  ),
                                ),
                              );
                            }
                          } else {
                            debugPrint(
                              'Mock Ad was not "watched" successfully or "failed". Redemption aborted.',
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Mock Ad not completed. Redemption failed.',
                                  ),
                                ),
                              );
                            }
                          }
                        }
                        : null, // Button is disabled if not enough points OR mock ad not "ready"
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  elevation: 5,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.card_giftcard, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Redeem Points (${stepTracker.totalPoints} / ${StepTracker.dailyRedemptionCap} daily)', // Updated button text
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (showAdLoadingIndicator) // Show loading indicator if mock ad is not "ready"
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: screenHeight * 0.03),

            // --- Emulator Mode Badge + Mock Steps Button ---
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
                    Provider.of<StepTracker>(
                      context,
                      listen: false,
                    ).addMockSteps(1000);
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
            showFireIcon: true,
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
            showFireIcon: false,
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
    bool showFireIcon = false,
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
