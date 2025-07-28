import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/services/database_service.dart';
import 'package:myapp/models/redeemed_reward_history_item.dart';
import 'package:intl/intl.dart';

class RewardHistoryPage extends StatefulWidget {
  // It's good practice to accept a Key, as RewardsPage is now passing it.
  const RewardHistoryPage({super.key});

  @override
  State<RewardHistoryPage> createState() => _RewardHistoryPageState();
}

class _RewardHistoryPageState extends State<RewardHistoryPage> {
  // Use a nullable Future so we can re-assign it.
  Future<List<RedeemedRewardHistoryItem>>? _rewardsFuture;

  @override
  void initState() {
    super.initState();
    _rewardsFuture = _fetchRewardHistory(); // Initial fetch
  }

  // No need for a separate _refresh method here if the parent passes a new Key.
  // The _rewardsFuture will be re-initialized in initState when the key changes.

  Future<List<RedeemedRewardHistoryItem>> _fetchRewardHistory() async {
    final userId = await DatabaseService().getDeviceId();
    debugPrint("History Page: Fetching rewards for userId: $userId");

    if (userId.isEmpty) { // Using .isEmpty directly as getDeviceId returns non-nullable String
      debugPrint("History Page: User ID is empty, cannot fetch reward history.");
      return [];
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('redeemed_rewards')
          .where('status', whereIn: ['completed', 'fulfilled', 'expired', 'pending'])
          .orderBy('timestamp', descending: true)
          .get();

      // <--- ADDED DEBUGGING ---
      debugPrint("History Page: Fetched ${snapshot.docs.length} redeemed reward documents.");
      if (snapshot.docs.isEmpty) {
        debugPrint("History Page: No documents found matching the query.");
      }
      for (var doc in snapshot.docs) {
        debugPrint("History Page: Document Data: ${doc.data()}");
      }
      // <--- END ADDED DEBUGGING ---

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return RedeemedRewardHistoryItem.fromFirestore(doc.id, data);
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('❌ History Page: Error fetching reward history: $e');
      debugPrint('Stack Trace: $stackTrace');
      return []; // Return empty list on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RedeemedRewardHistoryItem>>(
      future: _rewardsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('Error in RewardHistoryPage FutureBuilder: ${snapshot.error}');
          return Center(child: Text("Error loading history: ${snapshot.error}.\nPlease try again."));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No claimed or expired rewards yet."));
        }

        final rewards = snapshot.data!;

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rewards.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final reward = rewards[index];
            return _ClaimedGiftCard(
              imageUrl: reward.imageUrl, // <--- PASS THE IMAGE URL HERE
              icon: Icons.card_giftcard, // Default icon, as history items might not always have images
              title: reward.rewardName ?? 'Unknown Reward',
              subtitle: '${reward.pointsCost ?? 0} points',
              status: reward.status,
              date: reward.timestamp,
              giftCardCode: reward.giftCardCode,
              value: reward.value,
            );
          },
        );
      },
    );
  }
}

class _ClaimedGiftCard extends StatelessWidget {
  final String? imageUrl; // <--- ADDED: Optional image URL
  final IconData icon; // Keep this for fallback
  final String title;
  final String subtitle;
  final String status;
  final DateTime date;
  final String? giftCardCode;
  final num value;

  const _ClaimedGiftCard({
    this.imageUrl, // <--- ADDED to constructor
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.date,
    this.giftCardCode,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final dateString = DateFormat('MMM dd, yyyy').format(date);

    return Container(
      constraints: const BoxConstraints(minHeight: 100),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Conditional display logic for image vs icon
          if (imageUrl?.isNotEmpty == true)
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0), // Adjust for desired roundness
              child: Image.network( // Using Image.network
                imageUrl!, // Assert non-null as we've checked
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
            Icon(icon, size: 32, color: Colors.deepOrange), // Fallback icon

          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 4),
                // Display both value and subtitle (points cost)
                Text('\$${value.toStringAsFixed(2)} | $subtitle',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    )),
                const SizedBox(height: 4),
                Text('Claimed on: $dateString',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    )),
                if (giftCardCode != null && giftCardCode!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('Code: $giftCardCode',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        )),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _getStatusTextColor(status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green[100]!;
      case 'fulfilled':
        return Colors.green[100]!;
      case 'pending':
        return Colors.blue[100]!;
      case 'expired':
        return Colors.red[100]!;
      case 'cancelled':
        return Colors.grey[100]!;
      default:
        return Colors.grey[100]!;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green[700]!;
      case 'fulfilled':
        return Colors.green[700]!;
      case 'pending':
        return Colors.blue[700]!;
      case 'expired':
        return Colors.red[700]!;
      case 'cancelled':
        return Colors.grey[700]!;
      default:
        return Colors.grey[700]!;
    }
  }
}