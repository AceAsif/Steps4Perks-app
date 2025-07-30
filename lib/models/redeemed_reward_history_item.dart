import 'package:cloud_firestore/cloud_firestore.dart';

class RedeemedRewardHistoryItem {
  final String id;
  final String rewardType;
  final num value;
  final String status;
  final String? giftCardCode; // Made nullable as it might be 'pending'
  final DateTime timestamp;
  final String? rewardName; // Optional: store the name for history display
  final int? pointsCost; // Optional: store the cost for history display
  final String? imageUrl; // <--- ADD THIS LINE

  RedeemedRewardHistoryItem({
    required this.id,
    required this.rewardType,
    required this.value,
    required this.status,
    this.giftCardCode,
    required this.timestamp,
    this.rewardName,
    this.pointsCost,
    this.imageUrl, // <--- ADD THIS LINE
  });

  factory RedeemedRewardHistoryItem.fromFirestore(String id, Map<String, dynamic> data) {
    return RedeemedRewardHistoryItem(
      id: id,
      rewardType: data['rewardType'] as String? ?? '',
      value: data['value'] as num? ?? 0,
      status: data['status'] as String? ?? 'unknown',
      giftCardCode: data['giftCardCode'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rewardName: data['rewardName'] as String?,
      pointsCost: (data['pointsCost'] as num?)?.toInt(),
      imageUrl: data['imageUrl'] as String?, // <--- ADD THIS LINE
    );
  }
}