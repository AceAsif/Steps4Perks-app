import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/services/database_service.dart';
import 'package:myapp/view/rewardItem.dart';
import 'package:intl/intl.dart';

class RewardHistoryPage extends StatefulWidget {
  const RewardHistoryPage({super.key});

  @override
  State<RewardHistoryPage> createState() => _RewardHistoryPageState();
}

class _RewardHistoryPageState extends State<RewardHistoryPage> {
  late Future<List<RewardItem>> _rewardsFuture;

  @override
  void initState() {
    super.initState();
    _rewardsFuture = _fetchRewardHistory();
  }

  Future<List<RewardItem>> _fetchRewardHistory() async {
    final userId = await DatabaseService().getDeviceId();
    debugPrint("Fetching rewards for userId: $userId");

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('redeemed_rewards')
        .where('status', whereIn: ['fulfilled', 'expired'])
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return RewardItem.fromFirestore(doc.id, data);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RewardItem>>(
      future: _rewardsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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
              icon: Icons.card_giftcard,
              title: reward.rewardName,
              subtitle: '\$${reward.value} | ${reward.pointsCost} points',
              status: reward.status,
              date: reward.timestamp,
            );
          },
        );
      },
    );
  }
}

class _ClaimedGiftCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final DateTime date;

  const _ClaimedGiftCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
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
                Text(subtitle,
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
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: status == 'fulfilled'
                  ? Colors.green[100]
                  : Colors.orange[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: status == 'fulfilled'
                    ? Colors.green[700]
                    : Colors.orange[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
