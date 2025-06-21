import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StepsBarChart extends StatefulWidget {
  final List<String> labels; // Expecting: ['Mon', 'Tue', ..., 'Sun']
  final List<double> stepValues;

  const StepsBarChart({
    Key? key,
    required this.labels,
    required this.stepValues,
  }) : super(key: key);

  @override
  State<StepsBarChart> createState() => _StepsBarChartState();
}

class _StepsBarChartState extends State<StepsBarChart> {
  @override
  Widget build(BuildContext context) {
    final maxSteps = widget.stepValues.reduce((a, b) => a > b ? a : b);
    final maxY = (maxSteps <= 15000 ? 15000 : (maxSteps * 1.2)).clamp(0, 20000).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        reservedSize: 36,
                        getTitlesWidget: (value, _) {
                          if (value % 5000 == 0) {
                            return Text('${(value / 1000).toStringAsFixed(0)}k',
                                style: const TextStyle(fontSize: 10));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(widget.stepValues.length, (index) {
                    final value = widget.stepValues[index];
                    final base = value.clamp(0, 6000).toDouble();
                    final above = value > 6000 ? value - 6000 : 0;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                          rodStackItems: [
                            BarChartRodStackItem(0, base, Colors.red),
                            if (above > 0)
                              BarChartRodStackItem(base, value, Colors.lightBlueAccent),
                          ],
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