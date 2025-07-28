import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/view/rewardshistory.dart';
import 'package:myapp/services/database_service.dart';
import 'package:myapp/models/available_reward_item.dart'; // <--- NEW IMPORT
import 'package:myapp/models/redeemed_reward_history_item.dart'; // <--- NEW IMPORT (though not directly used in this file's UI, it's good for context)


class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  int _selectedTab = 0;
  List<AvailableRewardItem> _rewards = []; // <--- CHANGE TYPE HERE
  bool _isLoadingAvailableRewards = true; // <--- ADD THIS LOADING STATE

  // <--- ADD THIS VARIABLE ---
  Key _historyPageKey = UniqueKey(); // Initial key for RewardHistoryPage
  // <--- END ADDED VARIABLE ---

  @override
  void initState() {
    super.initState();
    _loadAvailableRewards();
    // Also load total points when the page initializes to ensure it's up to date
    // listen: false because we are just calling a method, not setting up a listener.
    Provider.of<StepTracker>(context, listen: false).loadTotalPointsFromDB();
  }

  Future<void> _refresh() async {
    // Set loading state for refresh
    setState(() {
      _isLoadingAvailableRewards = true;
    });
    // First, refresh total points from the database
    await Provider.of<StepTracker>(context, listen: false).loadTotalPointsFromDB();
    // Then, reload available rewards
    await _loadAvailableRewards(); // This will handle setting _isLoadingAvailableRewards to false
    // No need for a final setState here, _loadAvailableRewards handles its own state updates.
  }

  Future<void> _loadAvailableRewards() async {
    setState(() {
      _isLoadingAvailableRewards = true; // Set loading state
    });
    try {
      // No need for userId here as fetchAvailableRewards is global (from rewards_catalogue)
      final fetchedRewards = await DatabaseService().fetchAvailableRewards(); // <--- CALL NEW FUNCTION
      setState(() {
        _rewards = fetchedRewards;
        _isLoadingAvailableRewards = false; // Reset loading state on success
      });
    } catch (e) {
      debugPrint('Error loading available rewards: $e');
      setState(() {
        _rewards = []; // Clear rewards on error
        _isLoadingAvailableRewards = false; // Reset loading state on error
      });
      // Optionally, show a SnackBar or error message to the user
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
                _buildTabSwitch(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: _selectedTab == 0
                      ? _buildAvailableRewards(stepTracker)
                  // <--- MODIFIED HERE ---
                      : RewardHistoryPage(key: _historyPageKey), // <--- PASS THE KEY HERE
                  // <--- END MODIFIED HERE ---
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
        onTap: () { // <--- MODIFIED HERE
          setState(() {
            _selectedTab = index;
            // <--- ADD THIS LOGIC ---
            // If switching to History tab, generate a new key to force rebuild
            if (_selectedTab == 1) {
              _historyPageKey = UniqueKey();
            }
            // <--- END ADDED LOGIC ---
          });
        }, // <--- END MODIFIED HERE
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
    if (_isLoadingAvailableRewards) { // <--- Handle loading state for available rewards
      return const Center(child: CircularProgressIndicator());
    }
    if (_rewards.isEmpty) {
      return const Center(child: Text('No available rewards at the moment. Check back later!'));
    }

    return Column(
      children: _rewards.map((reward) {
        final canClaim = tracker.totalPoints >= reward.pointsCost;
        // Avoid division by zero if pointsCost is 0
        final progress = reward.pointsCost > 0 ? tracker.totalPoints / reward.pointsCost : 0.0;

        return _buildRewardCard(
          icon: Icons.card_giftcard, // <--- Still pass a default icon for fallback
          imageUrl: reward.imageUrl, // <--- Pass the imageUrl from the AvailableRewardItem
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

  // MODIFIED: _handleRewardClaim now takes AvailableRewardItem and passes necessary data to addRedeemedReward
  Future<void> _handleRewardClaim(StepTracker tracker, AvailableRewardItem reward) async {
    // Pass the specific pointsCost of the reward to the redeemPoints method
    final redeemedPoints = await tracker.redeemPoints(reward.pointsCost); // <--- PASS POINTS COST

    if (redeemedPoints > 0) {
      // Add the redeemed reward to the user's history collection
      await DatabaseService().addRedeemedReward(
        rewardType: reward.rewardType,
        value: reward.value,
        status: 'completed', // Or 'pending', 'processing' if human action is needed
        giftCardCode: 'RWD-${DateTime.now().millisecondsSinceEpoch}', // Generate a simple unique code
        rewardName: reward.rewardName,   // <--- Pass the reward name for history
        pointsCost: reward.pointsCost,   // <--- Pass the points cost for history
        imageUrl: reward.imageUrl, // <--- PASS THE IMAGE URL HERE
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🎉 Redeemed ${reward.pointsCost} points for ${reward.rewardName}!')),
      );
      // Refresh available rewards (if any should disappear after claiming) and total points
      // Total points will automatically update via Provider listener if loadTotalPointsFromDB() is called by StepTracker.
      // Reloading available rewards might be unnecessary if rewards don't disappear after one claim.
      // But it's good practice for state consistency after an action.
      await _loadAvailableRewards(); // Reload to reflect any changes if applicable
      await Provider.of<StepTracker>(context, listen: false).loadTotalPointsFromDB(); // Ensure UI updates
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Not enough points to redeem.')),
      );
    }
  }

  Widget _buildRewardCard({
    required IconData icon,
    String? imageUrl,      // <--- This is the optional parameter
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
        children: [ // <--- This is the children list for the main Column
          Row( // <--- This is the Row widget
            children: [ // <--- This is the children list for the Row
              // Conditional display: Image if imageUrl exists, otherwise Icon
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0), // Adjust for desired roundness
                  child: Image.network( // Using Image.network for now
                    imageUrl,
                    width: 48, // Adjust size as needed
                    height: 48, // Adjust size as needed
                    fit: BoxFit.cover, // Ensures image covers the space
                    errorBuilder: (context, error, stackTrace) => Container( // Fallback for image loading error
                      width: 48, height: 48,
                      color: Colors.grey[200],
                      child: Icon(Icons.broken_image, color: Colors.grey[400]),
                    ),
                  ),
                )
              else
                Icon(icon, size: 32, color: progressColor), // Fallback icon

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
            ], // <--- CLOSING BRACKET FOR THE ROW'S CHILDREN LIST
          ),

          // These widgets belong directly in the Column's children, after the Row
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
        ], // <--- CLOSING BRACKET FOR THE COLUMN'S CHILDREN LIST
      ),
    );
  }
}