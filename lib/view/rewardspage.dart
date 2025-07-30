import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/view/rewardshistory.dart';
import 'package:myapp/services/database_service.dart';
import 'package:myapp/models/available_reward_item.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  int _selectedTab = 0; // Renamed from selectedTabIndex for consistency with RewardsPage's original code
  List<AvailableRewardItem> _rewards = [];
  bool _isLoadingAvailableRewards = true;

  Key _historyPageKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadAvailableRewards();
    Provider.of<StepTracker>(context, listen: false).loadTotalPointsFromDB();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoadingAvailableRewards = true;
    });
    await Provider.of<StepTracker>(context, listen: false).loadTotalPointsFromDB();
    await _loadAvailableRewards();
  }

  Future<void> _loadAvailableRewards() async {
    setState(() {
      _isLoadingAvailableRewards = true;
    });
    try {
      final fetchedRewards = await DatabaseService().fetchAvailableRewards();
      setState(() {
         _rewards = [
          ...fetchedRewards.where((r) => r.rewardType != 'booster'),
          ...fetchedRewards.where((r) => r.rewardType == 'booster'),
        ];
        _isLoadingAvailableRewards = false;
      });
    } catch (e) {
      debugPrint('Error loading available rewards: $e');
      setState(() {
        _rewards = [];
        _isLoadingAvailableRewards = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load rewards: ${e.toString()}')),
        );
      }
    }
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
                // MODIFIED: Padding to match ActivityPage for the tab switch
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 12.0),
                  child: _buildTabSwitch(),
                ),
                Padding(
                  padding: const EdgeInsets.all(20), // This padding is for the content below tabs
                  child: _selectedTab == 0
                      ? _buildAvailableRewards(stepTracker)
                      : RewardHistoryPage(key: _historyPageKey),
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

  // REFACTORED: _buildTabSwitch to match ActivityPage's outer container
  Widget _buildTabSwitch() {
    return Container(
      // Outer container styling copied from ActivityPage's Row parent
      decoration: BoxDecoration(
        color: Colors.transparent, // Background color for the segment control itself
        borderRadius: BorderRadius.circular(25), // Adjusted for desired roundness
      ),
      child: Row(
        children: [
          _buildTab("Available", 0),
          const SizedBox(width: 8), // Gap between tabs
          _buildTab("History", 1),
        ],
      ),
    );
  }

  // REFACTORED: _buildTab to match ActivityPage's _buildTabButton
  Expanded _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    final screenWidth = MediaQuery.of(context).size.width; // Get screen width for responsive sizing

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
            if (_selectedTab == 1) {
              _historyPageKey = UniqueKey();
            }
          });
        },
        child: Container(
          // Inner tab styling copied from ActivityPage's _buildTabButton
          padding: EdgeInsets.symmetric(vertical: screenWidth * 0.025), // Responsive vertical padding
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : const Color(0xFFE6E6E6), // Dark grey for unselected
            borderRadius: BorderRadius.circular(25), // Matched borderRadius
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black, // White text for selected, black for unselected
                fontWeight: FontWeight.w600, // Matched font weight
                fontSize: screenWidth * 0.04, // Responsive font size
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableRewards(StepTracker tracker) {
    if (_isLoadingAvailableRewards) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rewards.isEmpty) {
      return const Center(child: Text('No available rewards at the moment. Check back later!'));
    }

    return Column(
      children: _rewards.map((reward) {
        final canClaim = tracker.totalPoints >= reward.pointsCost;
        final progress = reward.pointsCost > 0 ? tracker.totalPoints / reward.pointsCost : 0.0;

        return _buildRewardCard(
          icon: Icons.card_giftcard,
          imageUrl: reward.imageUrl,
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

  Future<void> _handleRewardClaim(StepTracker tracker, AvailableRewardItem reward) async {
    final redeemedPoints = await tracker.redeemPoints(reward.pointsCost);

    if (redeemedPoints > 0) {
      await DatabaseService().addRedeemedReward(
        rewardType: reward.rewardType,
        value: reward.value,
        status: 'completed',
        giftCardCode: 'RWD-${DateTime.now().millisecondsSinceEpoch}',
        rewardName: reward.rewardName,
        pointsCost: reward.pointsCost,
        imageUrl: reward.imageUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🎉 Redeemed ${reward.pointsCost} points for ${reward.rewardName}!')),
      );
      await _loadAvailableRewards();
      await Provider.of<StepTracker>(context, listen: false).loadTotalPointsFromDB();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Not enough points to redeem.')),
      );
    }
  }

  Widget _buildRewardCard({
    required IconData icon,
    String? imageUrl,
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
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 48, height: 48,
                      color: Colors.grey[200],
                      child: Icon(Icons.broken_image, color: Colors.grey[400]),
                    ),
                  ),
                )
              else
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