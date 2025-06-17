import 'package:flutter/material.dart';

// Example content for the Home page (replace with your actual Home page widget)
class HomePageContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(32.0),
        child: const Column(
          children: <Widget>[
             Text('Hello Asif'),
             // TODO: implement the Gauge functionality. Link: https://pub.dev/packages/syncfusion_flutter_gauges#add-radial-gauge-to-the-widget-tree
             // SfRadialGauge(), //This is the Radial Gauge
             Text('Daily Goal'),
              // TODO: implement the progress bar functionality.
             LinearProgressIndicator(
                value: 0.5, // The current progress (0.0 to 1.0)
                backgroundColor: Colors.grey, // The background color of the track
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue), // The color of the progress indicator
              )
          ],
        ),
      );
  }
}
