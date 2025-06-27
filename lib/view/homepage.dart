import 'package:flutter/material.dart';
import 'package:myapp/features/step_gauge.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:provider/provider.dart';

class HomePageContent extends StatefulWidget {
const HomePageContent({super.key});

@override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  int oldSteps = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final stepTracker = Provider.of<StepTracker>(context);
    final currentSteps = stepTracker.currentSteps;

    // Store oldSteps to animate from previous to new value
    final animatedSteps = TweenAnimationBuilder<int>(
      tween: IntTween(begin: oldSteps, end: currentSteps),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Text(
          'Steps today: $value',
          style: TextStyle(
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        );
      },
      onEnd: () {
        oldSteps = currentSteps;
      },
    );

    final animatedGauge = TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: oldSteps.toDouble(),
        end: currentSteps.toDouble(),
      ),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return StepGauge(currentSteps: value.toInt());
      },
      onEnd: () {
        oldSteps = currentSteps;
      },
    );

    return SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: screenHeight * 0.03,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Hello Asif',
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(
                  width: screenWidth * 0.65,
                  height: screenWidth * 0.65,
                  child: animatedGauge,
                ),
                animatedSteps,
                Text(
                  '4 Day Streaks',
                  style: TextStyle(fontSize: screenWidth * 0.045),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Points earned today: ${(currentSteps / 100).floor()}/250',
                  style: TextStyle(fontSize: screenWidth * 0.045),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: screenHeight * 0.03),
                SizedBox(
                  width: screenWidth * 0.6,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Points redeem')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade800,
                      elevation: 4,
                    ),
                    child: const Text(
                      'Redeem points',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

  }
}
