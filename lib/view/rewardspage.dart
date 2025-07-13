import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RewardsPage extends StatelessWidget {
  const RewardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stepTracker = Provider.of<StepTracker>(context);
    final databaseService = DatabaseService();
    final currentUserId = databaseService.currentUserId;

    debugPrint('RewardsPage: Current User ID: $currentUserId'); // Keep this debug print

    // --- TEMPORARY: For testing without authentication ---
    // Remove this block when you implement proper user authentication flow.
    if (currentUserId == null) {
      debugPrint('RewardsPage: User ID is null, but proceeding for testing purposes.');
      // You could return a loading indicator here if you want to wait for auth state
      // return const Center(child: CircularProgressIndicator());
      // Or, if you want to force display even without auth:
      // return _buildRewardsContent(context, stepTracker, databaseService); // Call the content directly
    }
    // --- END TEMPORARY ---

    // The rest of your build method is the actual content
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
            // Available Rewards Tab
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Display current redeemable points
                  Text(
                    'Current Redeemable: ${stepTracker.totalPoints} / ${StepTracker.dailyRedemptionCap} daily',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  // Woolworths Gift Card
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.card_giftcard),
                      title: const Text('Woolworths \$50 Gift Card'),
                      subtitle: const Text('Redeemable at 2500 total points'),
                      trailing: ElevatedButton(
                        onPressed: stepTracker.canRedeemPoints
                            ? () async {
                                final int redeemedAmount = await stepTracker.redeemPoints();
                                if (context.mounted){
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
                  // Other available rewards...
                ],
              ),
            ),
            // Rewards History Tab (using StreamBuilder to fetch from Database)
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: databaseService.getRedeemedRewards(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final redeemedRewards = snapshot.data ?? [];
                if (redeemedRewards.isEmpty) {
                  return const Center(child: Text('No rewards claimed yet.'));
                }
                return ListView.builder(
                  itemCount: redeemedRewards.length,
                  itemBuilder: (context, index) {
                    final reward = redeemedRewards[index];
                    return ListTile(
                      title: Text(reward['rewardType'] ?? 'Unknown Reward'),
                      subtitle: Text('Value: ${reward['value'] ?? 0.0} points - Status: ${reward['status'] ?? 'N/A'}'),
                      trailing: Text(reward['timestamp'] != null
                          ? DateFormat('MMM dd, yyyy').format((reward['timestamp'] as Timestamp).toDate())
                          : 'N/A'),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
