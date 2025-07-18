import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // Required for date formatting

class StepsBarChart extends StatefulWidget {
  final List<String> labels; // ['Mon', 'Tue', ..., 'Sun']
  final List<double> stepValues; // Step values as doubles
  final String dateRange; // Title (e.g., "Activity for last 7 days")
  final int maxSteps; // Personal record value
  final String maxStepsDate; // Date string in 'yyyy-MM-dd' format

  const StepsBarChart({
    super.key,
    required this.labels,
    required this.stepValues,
    required this.dateRange,
    required this.maxSteps,
    required this.maxStepsDate,
  });

  @override
  State<StepsBarChart> createState() => _StepsBarChartState();
}

class _StepsBarChartState extends State<StepsBarChart> {
  String formatDate(String dateStr) {
    try {
      final DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy (E)').format(parsedDate);
    } catch (e) {
      return dateStr; // Fallback to raw input if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxSteps = widget.stepValues.isNotEmpty
        ? widget.stepValues.reduce((a, b) => a > b ? a : b)
        : 1000.0;

    double calculatedMaxY;
    if (maxSteps < 5000) {
      calculatedMaxY = 5000;
    } else if (maxSteps < 10000) {
      calculatedMaxY = 10000;
    } else if (maxSteps < 15000) {
      calculatedMaxY = 15000;
    } else {
      calculatedMaxY = (maxSteps * 1.2 / 5000).ceil() * 5000;
      if (calculatedMaxY < maxSteps * 1.1) {
        calculatedMaxY = (maxSteps * 1.1 / 5000).ceil() * 5000;
      }
    }
    final double maxY = calculatedMaxY.clamp(0, 100000).toDouble();
    const double barWidth = 14;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.dateRange,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

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
                          if (value == 0) return const Text('0k', style: TextStyle(fontSize: 10));
                          if (value % 5000 == 0) {
                            return Text('${(value / 1000).toInt()}k', style: const TextStyle(fontSize: 10));
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
                    getDrawingVerticalLine: (_) => const FlLine(
                      color: Colors.grey,
                      strokeWidth: 0.5,
                      dashArray: [2, 2],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(widget.stepValues.length, (index) {
                    final value = widget.stepValues[index];
                    const double stepGoal = 10000.0;

                    final rodStackItems = <BarChartRodStackItem>[
                      if (value <= stepGoal)
                        BarChartRodStackItem(0, value, Colors.red)
                      else ...[
                        BarChartRodStackItem(0, stepGoal, Colors.red),
                        BarChartRodStackItem(stepGoal, value, Colors.lightBlueAccent),
                      ],
                    ];

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

          const Text(
            'Personal Record',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            'Most Steps in a Day: ${widget.maxSteps}',
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            'Date: ${formatDate(widget.maxStepsDate)}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}