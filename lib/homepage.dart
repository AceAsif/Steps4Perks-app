import 'package:flutter/material.dart';
//This gauage library is needed to use the gauge functionality.
import 'package:syncfusion_flutter_gauges/gauges.dart';

//This is the content for the Home page.
class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {

 @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.all(32.0),
        child: Column(
          children: <Widget>[
             Text('Hello Asif',
                  style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontStyle: FontStyle.italic,
                  ),
              ),
             // TODO: implement the Gauge functionality. Link: https://pub.dev/packages/syncfusion_flutter_gauges#add-radial-gauge-to-the-widget-tree
             SfRadialGauge(), //This is the Radial Gauge
             Text('Daily Goal'),
              // TODO: implement the progress bar functionality.
             LinearProgressIndicator(
                value: 0.5, // The current progress (0.0 to 1.0)
                backgroundColor: Colors.grey, // The background color of the track
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue), // The color of the progress indicator
              ),
              // TODO: implement the redeem button functionality.
              ElevatedButton(
                onPressed: () {
                  // Do something when the button is pressed
                  Text('Button pressed!');
                },
                child: const Text('Redeem'),
              )
          ],
        ),
      );
  }
}
