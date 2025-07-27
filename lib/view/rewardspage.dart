import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/view/rewardshistory.dart';
import 'package:myapp/services/database_service.dart';
import '../view/rewardItem.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  int _selectedTab = 0;
  List<RewardItem> _rewards = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableRewards();
  }

  Future<void> _refresh() async {
    await Provider.of<StepTracker>(context, listen: false).loadTotalPointsFromDB();
    await _loadAvailableRewards();
    setState(() {});
  }

  Future<void> _loadAvailableRewards() async {
    final userId = await DatabaseService().getDeviceId();
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('redeemed_rewards')
        .where('status', isEqualTo: 'active')
        .get();

    setState(() {
      _rewards = snapshot.docs
          .map((doc) => RewardItem.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stepTracker = Provider.of<StepTracker>(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotalPoints(stepTracker),
                _buildTabSwitch(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: _selectedTab == 0
                      ? _buildAvailableRewards(stepTracker)
                      : const RewardHistoryPage(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalPoints(StepTracker tracker) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        'Total Points: ${tracker.totalPoints}',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTabSwitch() {
    return Container(
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
    );
  }

  Expanded _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableRewards(StepTracker tracker) {
    if (_rewards.isEmpty) {
      return const Center(child: Text('No available rewards'));
    }

    return Column(
      children: _rewards.map((reward) {
        final canClaim = tracker.totalPoints >= reward.pointsCost;
        final progress = tracker.totalPoints / reward.pointsCost;

        return _buildRewardCard(
          icon: Icons.card_giftcard,
          title: reward.rewardName,
          subtitle: '${tracker.totalPoints} / ${reward.pointsCost} points',
          progress: progress,
          enabled: canClaim,
          progressColor: Colors.green,
          onPressed: () => _handleRewardClaim(tracker, reward),
        );
      }).toList(),
    );
  }

  Future<void> _handleRewardClaim(StepTracker tracker, RewardItem reward) async {
    final redeemed = await tracker.redeemPoints();

    if (redeemed > 0) {
      await DatabaseService().addRedeemedReward(
        rewardType: reward.rewardType,
        value: reward.value,
        status: 'completed',
        giftCardCode: 'RWD-${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🎉 Redeemed $redeemed points!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Not enough points to redeem.')),
      );
    }
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
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 32, color: progressColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ElevatedButton(
                onPressed: enabled ? onPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: enabled ? Colors.black : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Claim'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 10),
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
