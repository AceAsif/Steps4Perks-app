import 'package:flutter/material.dart';
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
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final stepTracker = Provider.of<StepTracker>(context);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Total Points
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'Total Points: ${stepTracker.totalPoints}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          /// Tab Switch
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              children: [
                _buildTab('Available', 0),
                _buildTab('History', 1),
              ],
            ),
          ),

          /// Tab Content
          Expanded(
            child: selectedTab == 0
                ? _buildAvailableRewards(stepTracker)
                : const RewardHistoryPage(),
          ),
        ],
      ),
    );
  }

  Expanded _buildTab(String text, int index) {
    bool isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => selectedTab = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableRewards(StepTracker stepTracker) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildRewardCard(
          icon: Icons.card_giftcard,
          title: 'Woolworths \$25 Gift Card',
          subtitle: '${stepTracker.totalPoints} / 2500 points',
          progress: stepTracker.totalPoints / 2500,
          enabled: stepTracker.totalPoints >= 2500,
          onPressed: () async {
          final redeemedAmount = await stepTracker.redeemPoints();
          if (redeemedAmount > 0) {
            final databaseService = DatabaseService();
            await databaseService.addRedeemedReward(
              rewardType: 'gift_card',
              value: 50,
              status: 'completed',
              giftCardCode: 'W50-XYZ-123',
            );

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Redeemed $redeemedAmount points!')),
              );
            }
          }
        },
          progressColor: Colors.green,

        ),
      ],
    );
  }

  Widget _buildRewardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required double progress,
    required bool enabled,
    required VoidCallback onPressed,
    Color progressColor = Colors.blue,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Top Row
          Row(
            children: [
              Icon(icon, size: 32, color: progressColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: enabled ? onPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: enabled ? Colors.black : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Claim'),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 10),

          /// Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }
}
