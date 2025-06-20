import 'package:flutter/material.dart';
import 'package:myapp/features/step_gauge.dart';
import 'package:myapp/view/rewardspage.dart'; // Import the RewardsPage


//This is the content for the Home page.
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

    return SafeArea( // Ensures content stays within safe screen bounds (avoids status bar & notches)
      child: SingleChildScrollView( // Makes the entire screen scrollable to prevent overflow
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.08,
          vertical: screenHeight * 0.02,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Hello Asif',
              style: TextStyle(
                fontSize: screenWidth * 0.05,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                fontStyle: FontStyle.italic,
              ),
            ),

            SizedBox(height: screenHeight * 0.02),

            // Gauge wrapped in a SizedBox for responsive scaling
            SizedBox(
              width: screenWidth * 0.65, // 65% of screen width
              height: screenWidth * 0.65, // Square ratio
              // Call the function from step_gauge.dart
              child: StepGauge(currentSteps: currentSteps), // Pass dynamic value 
            ),
            SizedBox(height: screenHeight * 0.02),

            Text(
              'Daily Goal',
              style: TextStyle(fontSize: screenWidth * 0.045),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              '0 / 10,000 Steps',
              style: TextStyle(fontSize: screenWidth * 0.045),
            ),

            SizedBox(height: screenHeight * 0.02),

           Container(
              width: MediaQuery.of(context).size.width * 0.75,
              height: MediaQuery.of(context).size.height * 0.015,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: 0.5,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),

            SizedBox(height: screenHeight * 0.03),

            SizedBox(
              width: screenWidth * 0.6,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RewardsPage()), // Navigate to RewardsPage
                  ); // Navigate to RewardsPage
                },
                // Navigate to RewardsPage
                child: const Text('Redeem'),
              ),
              /* 
              //This code is for testing the gauge bar and can removed after the app is complete
              child: ElevatedButton(
                onPressed: simulateStepIncrease,
                child: const Text("Add 500 Steps"),
              ),*/
            ),
          ],
        ),
      ),
    );
  }
}
