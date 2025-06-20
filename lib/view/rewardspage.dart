import 'package:flutter/material.dart';
import 'package:myapp/features/giftcard.dart'; // This calls the giftcard.dart file to use the gift card.
import 'package:myapp/features/stepbooster.dart'; // This calls the stepbooster.dart file to use the step booster.


class RewardsPage extends StatefulWidget {
  const RewardsPage({Key? key}) : super(key: key);

  @override
  _RewardsPageState createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  int selectedTabIndex = 0; // 0 = Available, 1 = History

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.0),
          child: Text('Rewards'),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10.0), // more space from screen edge
            child: Row(
              children: [
                _buildTabButton("Available", 0, screenWidth),
                const SizedBox(width: 12),
                _buildTabButton("History", 1, screenWidth),
              ],
            ),
          ),
          Expanded(
            child: selectedTabIndex == 0
            ? ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  GiftCard(
                    icon: Icons.card_giftcard,
                    title: 'Woolworths',
                    subtitle: '\$25 Gift Card',
                    progressText: '10,000 steps × 10 days',
                    progressValue: 0.0,
                  ),
                  const SizedBox(height: 12),
                  const StepBoosterCard(), // Now included from stepbooster.dart
                ],
              )
            : const Center(child: Text("History Rewards List")),
          )
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, double screenWidth) {
    final isSelected = selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : const Color.fromARGB(255, 213, 212, 212),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: screenWidth * 0.04,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
