import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/giftcard.dart'; // This calls the giftcard.dart file to use the gift card.
import 'package:myapp/features/stepbooster.dart'; // This calls the stepbooster.dart file to use the step booster.
import 'package:myapp/features/step_tracker.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  RewardsPageState createState() => RewardsPageState();
}

class RewardsPageState extends State<RewardsPage> {
  //It creates a GlobalKey that allows you to access and interact with the internal state of
  // the StepBoosterCard widget from outside its class (typically from the parent widget).
  final GlobalKey<StepBoosterCardState> _boosterKey =
      GlobalKey<StepBoosterCardState>();
  int selectedTabIndex = 0; // 0 = Available, 1 = History

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final stepTracker = Provider.of<StepTracker>(context);
    final tracker = Provider.of<StepTracker>(context);
    final steps = tracker.currentSteps;
    final dailyPoints = tracker.dailyPoints;
    int totalPoints = tracker.totalPoints;
    final canRedeem = tracker.canRedeemGiftCard;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // removing rewards as it seems not needed
            // const Text(
            //   'Rewards',
            //   style: TextStyle(fontWeight: FontWeight.bold),
            // ),
            Text(
              'Total Points: $totalPoints',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 30.0,
              vertical: 10.0,
            ), // more space from screen edge
            child: Row(
              children: [
                _buildTabButton("Available", 0, screenWidth),
                const SizedBox(width: 12),
                _buildTabButton("History", 1, screenWidth),
              ],
            ),
          ),
          Expanded(
            child:
                selectedTabIndex == 0
                    ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        GiftCard(
                          icon: Icons.card_giftcard,
                          title: 'Woolworths',
                          subtitle: '\$25 Gift Card',
                          progressText: '$totalPoints / 2,500 points',
                          progressValue: totalPoints / 2500,
                          isClaimable: totalPoints >= 2500,
                          onClaimPressed: () {
                            setState(() {
                              totalPoints -= 2500;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gift card claimed!'),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),
                        StepBoosterCard(
                          key: _boosterKey,
                        ), // Now included from stepbooster.dart
                      ],
                    )
                    : const Center(child: Text("History Rewards List")),
          ),
        ],
      ),

      /*
      /// ✅ Here's the floating action button
      floatingActionButton: selectedTabIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                // Increment the booster progress by 20%
                _boosterKey.currentState?.increaseProgress(0.2);
              },
              backgroundColor: Colors.orange,
              child: const Icon(Icons.play_arrow),
              tooltip: 'Simulate Ad Watch',
            )
          : null,
          
      // ✅ Set FAB location
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    */
    );
  }

  Widget _buildTabButton(String label, int index, double screenWidth) {
    final isSelected = selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? Colors.black
                    : const Color.fromARGB(255, 213, 212, 212),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: screenWidth * 0.04,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
