import 'package:flutter/material.dart';

class RewardHistoryPage extends StatelessWidget {
  const RewardHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: const [
        _ClaimedGiftCard(
          icon: Icons.card_giftcard,
          title: 'Woolworths',
          subtitle: '\$25 Gift Card',
        ),
        SizedBox(height: 12),
        _ClaimedGiftCard(
          icon: Icons.card_giftcard,
          title: 'Amazon',
          subtitle: '\$10 Gift Card',
        ),
      ],
    );
  }
}

class _ClaimedGiftCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ClaimedGiftCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: screenWidth * 0.12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title\n$subtitle',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black54,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text("Claimed"),
          ),
        ],
      ),
    );
  }
}
