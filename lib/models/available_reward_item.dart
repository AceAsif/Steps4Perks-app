import 'package:cloud_firestore/cloud_firestore.dart';

class AvailableRewardItem {
  final String id;
  final String rewardName;
  final String rewardType;
  final int pointsCost;
  final num value; // Use num for consistency if value can be decimal
  final String? description; // Optional: add description for catalog
  final String? imageUrl; // Optional: add image URL

  AvailableRewardItem({
    required this.id,
    required this.rewardName,
    required this.rewardType,
    required this.pointsCost,
    required this.value,
    this.description,
    this.imageUrl,
  });

  factory AvailableRewardItem.fromFirestore(String id, Map<String, dynamic> data) {
    return AvailableRewardItem(
      id: id,
      rewardName: data['rewardName'] as String? ?? 'Unnamed Reward',
      rewardType: data['rewardType'] as String? ?? '',
      pointsCost: (data['pointsCost'] as num?)?.toInt() ?? 0,
      value: data['value'] as num? ?? 0,
      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
    );
  }
}