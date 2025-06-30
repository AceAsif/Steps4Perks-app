import 'package:flutter/material.dart';
import 'package:myapp/features/step_gauge.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:provider/provider.dart';

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  HomePageContentState createState() => HomePageContentState();
}

class HomePageContentState extends State<HomePageContent> {
  int _oldSteps = 0;

  int get oldSteps => _oldSteps;

  @override
  Widget build(BuildContext context) {
    final stepTracker = Provider.of<StepTracker>(context);
    final currentSteps = stepTracker.currentSteps;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: screenHeight * 0.001,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildGauge(screenWidth, screenHeight, currentSteps),
              //_buildStepCountText(screenWidth, currentSteps),
              _buildSummaryCards(currentSteps),
              SizedBox(height: screenHeight * 0.03),
              _buildRedeemButton(screenWidth),
              SizedBox(height: screenHeight * 0.03),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGauge(
    double screenWidth,
    double screenHeight,
    int currentSteps,
  ) {
    return SizedBox(
      width: screenWidth * 0.65,
      height: screenWidth * 0.65,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: _oldSteps.toDouble(),
          end: currentSteps.toDouble(),
        ),
        duration: const Duration(milliseconds: 600),
        builder: (context, value, child) {
          return StepGauge(currentSteps: value.toInt());
        },
        onEnd: () {
          _oldSteps = currentSteps;
        },
      ),
    );
  }

  /*
  Widget _buildStepCountText(double screenWidth, int currentSteps) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: _oldSteps, end: currentSteps),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
          child: Text(
            'Steps today: $value',
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
      onEnd: () {
        _oldSteps = currentSteps;
      },
    );
  }*/

  Widget _buildSummaryCards(int currentSteps) {
    return Row(
      children: [
        Expanded(
          child: _buildCard(
            label: 'Daily Streak',
            value: '4',
            showFireIcon: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCard(
            label: 'Points Earned',
            value: '${(currentSteps / 100).floor()} / 250',
            showFireIcon: false, // No fire emoji here
          ),
        ),
      ],
    );
  }



 //This is modifing the cards size.
  Widget _buildCard({
  required String label,
  required String value,
  bool showFireIcon = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text.rich(
            TextSpan(
              children: [
                if (showFireIcon)
                  const TextSpan(
                    text: '🔥 ',
                    style: TextStyle(fontSize: 20),
                  ),
                TextSpan(
                  text: label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildRedeemButton(double screenWidth) {
    return SizedBox(
      width: screenWidth * 0.75,
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Points redeem')));
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.card_giftcard, size: 24), // Gift icon
            SizedBox(width: 8),
            Text(
              'Redeem Points',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
