import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class StepChartShimmer extends StatelessWidget {
  const StepChartShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(7, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Container(
              height: 20,
              width: double.infinity,
              color: Colors.white,
            ),
          );
        }),
      ),
    );
  }
}
