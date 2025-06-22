import 'package:flutter/material.dart';
import 'package:myapp/features/step_gauge.dart';

class HomePageContent extends StatefulWidget {
const HomePageContent({super.key});

@override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  int currentSteps = 0;

  void simulateStepIncrease() {
  setState(() {
  currentSteps += 500; // Simulate 500 more steps
  });
  }

  @override
  Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
    return SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05, // optional mild padding
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

                // Gauge chart
                SizedBox(
                  width: screenWidth * 0.65,
                  height: screenWidth * 0.65,
                  child: StepGauge(currentSteps: currentSteps),
                  //child: ColoredRangeGauge(value: 90),
                ),

                Text(
                  '4 Day Streaks',
                  style: TextStyle(fontSize: screenWidth * 0.045),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Points earned today: 0/250',
                  style: TextStyle(fontSize: screenWidth * 0.045),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: screenHeight * 0.03),

                // Redeem button
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

                // Optional: Simulate steps button (testing only)
                /*
                SizedBox(height: screenHeight * 0.02),
                ElevatedButton(
                  onPressed: simulateStepIncrease,
                  child: const Text("Add 500 Steps"),
                ),
                */
              ],
            ),
          ),
        ),
      ),
    );
  }
}