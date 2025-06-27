import 'package:flutter/material.dart';
import 'package:myapp/features/step_gauge.dart';
import 'package:pedometer/pedometer.dart';

class HomePageContent extends StatefulWidget {
const HomePageContent({super.key});

@override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  int currentSteps = 0;
  late Stream<StepCount> _stepCountStream;

  @override
  void initState() {
    super.initState();
    initPedometer();
  }

  void initPedometer() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen(
      onStepCount,
      onError: onStepCountError,
      onDone: () => debugPrint("Pedometer stream closed"),
      cancelOnError: true,
    );
  }

  void onStepCount(StepCount event) {
    setState(() {
      currentSteps = event.steps;
    });
  }

  void onStepCountError(error) {
    debugPrint("Pedometer error: $error");
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
                  child: StepGauge(currentSteps: currentSteps),
                ),

                // New step count text
                Text(
                  'Steps today: $currentSteps',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

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
