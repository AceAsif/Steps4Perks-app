import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/view/rewardshistory.dart';
import 'package:myapp/services/database_service.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final DatabaseService _databaseService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final stepTracker = Provider.of<StepTracker>(context);

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
            // Tab 1: Available Rewards
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Current Redeemable: ${stepTracker.totalPoints} / ${StepTracker.dailyRedemptionCap} daily',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),

                  /// 🔹 Gift Card Redemption Card
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.card_giftcard),
                      title: const Text('Woolworths \$50 Gift Card'),
                      subtitle: const Text('Redeemable at 2500 total points'),
                      trailing: ElevatedButton(
                        onPressed: stepTracker.canRedeemPoints
                            ? () async {
                                final int redeemedAmount =
                                    await stepTracker.redeemPoints();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Redeemed $redeemedAmount points for gift card!',
                                      ),
                                    ),
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

            // Tab 2: Rewards History
            const RewardHistoryPage(),
          ],
        ),
      ),
    );
  }
}
