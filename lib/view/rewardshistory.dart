import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/services/database_service.dart';
import 'package:myapp/models/redeemed_reward_history_item.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class RewardHistoryPage extends StatefulWidget {
  const RewardHistoryPage({super.key});

  @override
  State<RewardHistoryPage> createState() => _RewardHistoryPageState();
}

class _RewardHistoryPageState extends State<RewardHistoryPage> {
  Future<List<RedeemedRewardHistoryItem>>? _rewardsFuture;

  @override
  void initState() {
    super.initState();
    _rewardsFuture = _fetchRewardHistory();
  }

  Future<List<RedeemedRewardHistoryItem>> _fetchRewardHistory() async {
    final userId = DatabaseService().getUserId();
    debugPrint("History Page: Fetching rewards for userId: $userId");

    if (userId == null || userId.isEmpty) {
      debugPrint("History Page: User ID is empty or null, cannot fetch reward history.");
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

      debugPrint("History Page: Fetched ${snapshot.docs.length} redeemed reward documents.");
      for (var doc in snapshot.docs) {
        debugPrint("History Page: Document Data: ${doc.data()}");
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return RedeemedRewardHistoryItem.fromFirestore(doc.id, data);
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('❌ History Page: Error fetching reward history: $e');
      debugPrint('Stack Trace: $stackTrace');
      return [];
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

            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Slidable(
                key: ValueKey(reward.id),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (_) async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Delete Reward?"),
                            content: const Text("Are you sure you want to delete this reward from history?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
                              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Delete")),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          final userId = DatabaseService().getUserId();
                          if (userId != null) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .collection('redeemed_rewards')
                                .doc(reward.id)
                                .delete();

                            setState(() {
                              _rewardsFuture = _fetchRewardHistory();
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reward deleted')),
                            );
                          }
                        }
                      },
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                    ),
                  ],
                ),
                child: _ClaimedGiftCard(
                  imageUrl: reward.imageUrl,
                  icon: Icons.card_giftcard,
                  title: reward.rewardName ?? 'Unknown Reward',
                  subtitle: '${reward.pointsCost ?? 0} points',
                  status: reward.status,
                  date: reward.timestamp,
                  giftCardCode: reward.giftCardCode,
                  value: reward.value,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ClaimedGiftCard extends StatelessWidget {
  final String? imageUrl;
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final DateTime date;
  final String? giftCardCode;
  final num value;

  const _ClaimedGiftCard({
    this.imageUrl,
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
          if (imageUrl?.isNotEmpty == true)
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                imageUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey[200],
                  child: Icon(Icons.broken_image, color: Colors.grey[400]),
                ),
              ),
            )
          else
            Icon(icon, size: 32, color: Colors.deepOrange),

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
