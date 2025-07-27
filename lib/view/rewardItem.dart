import 'package:cloud_firestore/cloud_firestore.dart';

class RewardItem {
  final String id;
  final String rewardName;
  final String rewardType;
  final String status;
  final String giftCardCode;
  final int pointsCost;
  final int value;
  final DateTime timestamp;

  RewardItem({
    required this.id,
    required this.rewardName,
    required this.rewardType,
    required this.status,
    required this.giftCardCode,
    required this.pointsCost,
    required this.value,
    required this.timestamp,
  });

  factory RewardItem.fromFirestore(String id, Map<String, dynamic> data) {
    return RewardItem(
      id: id,
      rewardName: data['rewardName'] ?? '',
      rewardType: data['rewardType'] ?? '',
      status: data['status'] ?? '',
      giftCardCode: data['giftCardCode'] ?? '',
      pointsCost: data['pointsCost'] ?? 0,
      value: data['value'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
