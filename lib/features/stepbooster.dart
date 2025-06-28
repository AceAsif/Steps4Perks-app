import 'package:flutter/material.dart';

class StepBoosterCard extends StatefulWidget {
  const StepBoosterCard({super.key});

  @override
  StepBoosterCardState createState() => StepBoosterCardState();
}

class StepBoosterCardState extends State<StepBoosterCard> {
  double progressValue = 0.3;

  void increaseProgress(double increment) {
    setState(() {
      progressValue += increment;
      if (progressValue > 1.0) progressValue = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt, size: screenWidth * 0.12, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step Booster\nWatch ads to boost',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Watch 5 ads to activate 2× booster',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 4,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed:
                progressValue >= 1.0
                    ? () {
                      // Handle booster activation
                    }
                    : null,
            child: const Text("Claim"),
          ),
        ],
      ),
    );
  }
}