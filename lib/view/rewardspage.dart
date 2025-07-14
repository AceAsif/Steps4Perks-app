import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/step_tracker.dart';

// --- NEW: Import the separate RewardHistoryPage ---
import 'package:myapp/view/rewardshistory.dart'; // Import the new file

class RewardsPage extends StatefulWidget { // Keep this as StatefulWidget if it manages DefaultTabController
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  // If RewardsPage itself doesn't need a stream, you can remove _redeemedRewardsStream here.
  // The RewardHistoryPage will manage its own stream.

  @override
  Widget build(BuildContext context) {
    final stepTracker = Provider.of<StepTracker>(context);
    // final databaseService = DatabaseService(); // No longer needed directly here
    // final currentUserId = databaseService.currentUserId; // No longer needed directly here

    // The check for currentUserId should ideally be handled at a higher level
    // (e.g., a wrapper around Bottomnavigation) or within RewardHistoryPage itself.
    // For now, RewardHistoryPage will handle its own check.

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rewards'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Available'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Available Rewards Tab (your existing content)
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Current Redeemable: ${stepTracker.totalPoints} / ${StepTracker.dailyRedemptionCap} daily',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.card_giftcard),
                      title: const Text('Woolworths \$50 Gift Card'),
                      subtitle: const Text('Redeemable at 2500 total points'),
                      trailing: ElevatedButton(
                        onPressed: stepTracker.canRedeemPoints
                            ? () async {
                                final int redeemedAmount = await stepTracker.redeemPoints();
                                if (context.mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Redeemed $redeemedAmount points for gift card!')),
                                  );
                                }
                              }
                            : null,
                        child: const Text('Redeem'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // History Tab: Use the new RewardHistoryPage
            const RewardHistoryPage(), // <-- NEW: Use your separate history page
          ],
        ),
      ),
    );
  }
}