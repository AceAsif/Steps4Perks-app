import 'package:flutter/material.dart';
/*
import 'package:provider/provider.dart';
import 'package:myapp/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
*/

/// Displays the history of claimed rewards, fetching data from Firebase Firestore.
class RewardHistoryPage extends StatefulWidget {
  const RewardHistoryPage({super.key});

  @override
  State<RewardHistoryPage> createState() => _RewardHistoryPageState();
}

class _RewardHistoryPageState extends State<RewardHistoryPage> {
  // DatabaseService instance can be final here as it doesn't depend on BuildContext
  //final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    // No stream initialization here anymore. It will be done inside the builder.
    debugPrint('RewardHistoryPage: initState called. DatabaseService initialized.');
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Reward history feature is coming soon!',
        style: TextStyle(fontSize: 16),
      ),
    );
  }
}

/*
/// A widget to display a single claimed gift card/reward in the history.
class _ClaimedGiftCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Timestamp? timestamp;

  const _ClaimedGiftCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bodyTextColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

    final String dateString = timestamp != null
        ? DateFormat('MMM dd, yyyy HH:mm').format(timestamp!.toDate())
        : 'Date N/A';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: screenWidth * 0.12, color: Colors.deepOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: bodyTextColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: screenWidth * 0.038,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Claimed on: $dateString',
                  style: TextStyle(
                    fontSize: screenWidth * 0.03,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: status == 'fulfilled' ? Colors.green[100] : Colors.orange[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: screenWidth * 0.035,
                fontWeight: FontWeight.bold,
                color: status == 'fulfilled' ? Colors.green[700] : Colors.orange[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
*/
