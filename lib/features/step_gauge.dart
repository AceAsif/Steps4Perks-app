import 'package:flutter/material.dart';
//This gauage library is needed to use the gauge functionality.
import 'package:syncfusion_flutter_gauges/gauges.dart';

class StepGauge extends StatelessWidget {
  final int currentSteps; // e.g., 3200
  final int goalSteps;    // e.g., 10000

  const StepGauge({
    super.key,
    required this.currentSteps,
    this.goalSteps = 10000,
  });

  @override
  Widget build(BuildContext context) {
    //double progressValue = (currentSteps / goalSteps).clamp(0.0, 1.0);

    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: goalSteps.toDouble(),
          interval: goalSteps / 5, // Shows 0, 2000, 4000, etc.
          startAngle: 150, // left-side bottom
          endAngle: 30,    // right-side bottom
          showTicks: true, // This shows the marks near the number.
          showLastLabel: true,
          canScaleToFit: true, // ensures full range including 10000 fits
          axisLineStyle: AxisLineStyle(
            thickness: 0.15,
            thicknessUnit: GaugeSizeUnit.factor,
            cornerStyle: CornerStyle.bothCurve,
            color: Colors.grey.shade300,
          ),
          pointers: <GaugePointer>[
            RangePointer(
              value: currentSteps.toDouble(),
              cornerStyle: CornerStyle.bothCurve,
              width: 0.15,
              sizeUnit: GaugeSizeUnit.factor,
              color: Colors.blueAccent,
              animationDuration: 1000,
              enableAnimation: true,
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              angle: 90,
              positionFactor: 0.01, // Moves it upward
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$currentSteps',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '/ $goalSteps Steps',
                    style: TextStyle(
                      fontSize: 16, // <-- increase from 14 to 16 or 18
                      fontWeight: FontWeight.w500, // optional: makes it bolder
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}