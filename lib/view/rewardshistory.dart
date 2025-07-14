import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Displays the history of claimed rewards, fetching data from Firebase Firestore.
class RewardHistoryPage extends StatefulWidget {
  const RewardHistoryPage({super.key});

  @override
  State<RewardHistoryPage> createState() => _RewardHistoryPageState();
}

class _RewardHistoryPageState extends State<RewardHistoryPage> {
  // DatabaseService instance can be final here as it doesn't depend on BuildContext
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    // No stream initialization here anymore. It will be done inside the builder.
    debugPrint('RewardHistoryPage: initState called. DatabaseService initialized.');
  }

  @override
  Widget build(BuildContext context) {
    // Listen to Firebase Auth state changes
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          // Show loading while waiting for authentication state
          debugPrint('RewardHistoryPage: Waiting for auth state...');
          return const Center(child: CircularProgressIndicator());
        }

        final User? user = authSnapshot.data;
        final String? currentUserId = user?.uid;

        debugPrint('RewardHistoryPage: Auth Stream User ID: $currentUserId');

        // If no user is authenticated, display a login prompt
        if (currentUserId == null) {
          debugPrint('RewardHistoryPage: User ID is null, displaying login prompt.');
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 50, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Please log in to see your reward history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // If user is authenticated, then build the StreamBuilder for rewards data
        // We now have a guaranteed non-null currentUserId here.
        // FIX: Initialize the stream directly here, after currentUserId is confirmed.
        debugPrint('RewardHistoryPage: User authenticated. Fetching rewards stream...');
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _databaseService.getRedeemedRewards(), // This will now get the correct user ID
          builder: (context, rewardsSnapshot) {
            if (rewardsSnapshot.connectionState == ConnectionState.waiting) {
              debugPrint('RewardHistoryPage: Waiting for rewards data...');
              return const Center(child: CircularProgressIndicator());
            }
            if (rewardsSnapshot.hasError) {
              debugPrint('RewardHistoryPage Rewards Stream Error: ${rewardsSnapshot.error}');
              return Center(child: Text('Error loading history: ${rewardsSnapshot.error}'));
            }

            final redeemedRewards = rewardsSnapshot.data ?? [];

            if (redeemedRewards.isEmpty) {
              debugPrint('RewardHistoryPage: No rewards claimed yet.');
              return const Center(child: Text('No rewards claimed yet.'));
            }

            debugPrint('RewardHistoryPage: Displaying ${redeemedRewards.length} rewards.');
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: redeemedRewards.length,
              itemBuilder: (context, index) {
                final reward = redeemedRewards[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _ClaimedGiftCard(
                    icon: Icons.card_giftcard,
                    title: reward['rewardType'] ?? 'Unknown Reward',
                    subtitle: 'Redeemed ${reward['value'] ?? 0.0} points',
                    status: reward['status'] ?? 'N/A',
                    timestamp: reward['timestamp'],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

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
