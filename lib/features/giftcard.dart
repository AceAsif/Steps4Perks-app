import 'package:flutter/material.dart';

class GiftCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String progressText;
  final double progressValue;

  final bool isClaimable;
  final VoidCallback? onClaimPressed;

  const GiftCard({
    super.key, // <- use_super_parameters here
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progressText,
    required this.progressValue,
    required this.isClaimable,
    required this.onClaimPressed,
  });

  @override
  State<GiftCard> createState() => _GiftCardState();
}

class _GiftCardState extends State<GiftCard> {
  late double currentProgress;
  bool isClaimed = false;

  @override
  void initState() {
    super.initState();
    currentProgress = widget.progressValue; // initialize with passed value
  }

  // Optional: Method to update progress (e.g., from button or event)
  void updateProgress(double newValue) {
    setState(() {
      currentProgress = newValue.clamp(0.0, 1.0);
    });
  }

  void _handleClaim() {
    if (widget.isClaimable && !isClaimed) {
      widget.onClaimPressed?.call();
      setState(() {
        isClaimed = true;
        currentProgress = 0.0; //Reset the progress bar
      });
    }
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
          Icon(widget.icon, size: screenWidth * 0.12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.title}\n${widget.subtitle}',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.progressText,
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: currentProgress,
                  minHeight: 4,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 🟨 Claim Button
          ElevatedButton(
            onPressed: (widget.isClaimable && !isClaimed) ? _handleClaim : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isClaimed
                      ? Colors.grey[400]
                      : (widget.isClaimable ? Colors.amber : Colors.grey[300]),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(isClaimed ? "Claimed" : "Claim"),
          ),
        ],
      ),
    );
  }
}
