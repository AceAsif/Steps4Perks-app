import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StepsBarChart extends StatefulWidget {
  final List<String> labels; // Expecting: ['Mon', 'Tue', ..., 'Sun']
  final List<double> stepValues;
  final String dateRange; // New property for the date range text

  const StepsBarChart({
    Key? key,
    required this.labels,
    required this.stepValues,
    required this.dateRange, // Make it required
  }) : super(key: key);

  @override
  State<StepsBarChart> createState() => _StepsBarChartState();
}

class _StepsBarChartState extends State<StepsBarChart> {
  @override
  Widget build(BuildContext context) {
    // Calculate max steps to determine the Y-axis range
    final double maxSteps = widget.stepValues.isNotEmpty
        ? widget.stepValues.reduce((a, b) => a > b ? a : b)
        : 1000.0; // Default if no step values

    // Determine maxY for the chart.
    double calculatedMaxY;
    if (maxSteps < 5000) {
      calculatedMaxY = 5000;
    } else if (maxSteps < 10000) {
      calculatedMaxY = 10000;
    } else if (maxSteps < 15000) {
      calculatedMaxY = 15000;
    } else {
      // If maxSteps is very high, round up to the nearest 5000 or 10000 multiple
      calculatedMaxY = (maxSteps * 1.2 / 5000).ceil() * 5000;
      // Ensure a minimum for very high steps so it's not too cramped
      if (calculatedMaxY < maxSteps * 1.1) {
        calculatedMaxY = (maxSteps * 1.1 / 5000).ceil() * 5000;
      }
    }
    final double maxY = calculatedMaxY.clamp(0, 100000).toDouble();

    // Adjust bar width based on number of bars for better spacing in weekly view
    // For weekly, we generally have 7 bars, so a fixed width of 14 is usually fine.
    // If you were using this for monthly 'per day' view, you'd make it smaller.
    const double barWidth = 14;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NEW: Add the date range text here
          Text(
            widget.dateRange,
            style: const TextStyle(
              fontSize: 18, // Adjust font size as needed
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16), // Add some space below the title

          // Container with border and chart
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < widget.labels.length) {
                            return SideTitleWidget(
                              meta: meta,
                              space: 8.0,
                              child: Text(
                                widget.labels[index],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, _) {
                          if (value == 0) {
                            return const Text('0k', style: TextStyle(fontSize: 10));
                          }
                          if (value % 5000 == 0) {
                            return Text('${(value / 1000).toInt()}k',
                                style: const TextStyle(fontSize: 10));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: true,
                    getDrawingHorizontalLine: (value) {
                      if (value % 5000 == 0) {
                        return const FlLine(
                          color: Colors.grey,
                          strokeWidth: 0.5,
                          dashArray: [2, 2],
                        );
                      }
                      return const FlLine(color: Colors.transparent);
                    },
                    getDrawingVerticalLine: (value) {
                      return const FlLine(
                        color: Colors.grey,
                        strokeWidth: 0.5,
                        dashArray: [2, 2],
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(widget.stepValues.length, (index) {
                    final value = widget.stepValues[index];
                    final double stepGoalThreshold = 6000.0;

                    List<BarChartRodStackItem> rodStackItems = [];

                    if (value <= stepGoalThreshold) {
                      rodStackItems.add(
                        BarChartRodStackItem(0, value, Colors.red),
                      );
                    } else {
                      rodStackItems.add(
                        BarChartRodStackItem(0, stepGoalThreshold, Colors.red),
                      );
                      rodStackItems.add(
                        BarChartRodStackItem(
                            stepGoalThreshold, value, Colors.lightBlueAccent),
                      );
                    }

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          width: barWidth,
                          borderRadius: BorderRadius.circular(4),
                          rodStackItems: rodStackItems,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Text below the chart
          const Text(
            'Personal Record',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Most Steps in a Day: 14,000',
            style: TextStyle(fontSize: 14),
          ),
          const Text(
            'Date: Nov 12',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}