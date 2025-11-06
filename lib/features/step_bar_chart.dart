import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:myapp/features/step_tracker.dart';

class StepsBarChart extends StatefulWidget {
  final List<String> labels;
  final List<double> stepValues;
  final String dateRange;
  final int maxSteps;
  final String maxStepsDate;

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
  // 🟢 DYNAMIC: Different target for weekly vs monthly
  late final double stepTarget;

  @override
  void initState() {
    super.initState();
    stepTarget = _calculateStepTarget();
  }

  /// 🟢 NEW: Calculate correct target based on view
  double _calculateStepTarget() {
    const int dailyTarget = StepTracker.streakStepTarget; // 10,000

    if (isWeekly) {
      // Weekly view: Each bar = 1 day, target = 10,000 steps/day
      return dailyTarget.toDouble();
    } else {
      // Monthly view: Each bar = 1 week, target = 70,000 steps/week
      return (dailyTarget * 7).toDouble();
    }
  }

  String formatDate(String dateStr) {
    try {
      final DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy (E)').format(parsedDate);
    } catch (e) {
      return dateStr;
    }
  }

  /// ✅ Check if this is a weekly or monthly chart
  bool get isWeekly => widget.labels.any((label) =>
  label.toLowerCase().contains('mon') ||
      label.toLowerCase().contains('tue') ||
      label.toLowerCase().contains('wed') ||
      label.toLowerCase().contains('thu') ||
      label.toLowerCase().contains('fri') ||
      label.toLowerCase().contains('sat') ||
      label.toLowerCase().contains('sun'));

  @override
  Widget build(BuildContext context) {
    // ✅ Safety check: Ensure labels and values have the same length
    if (widget.labels.isEmpty || widget.stepValues.isEmpty) {
      return _buildEmptyChart();
    }

    if (widget.labels.length != widget.stepValues.length) {
      debugPrint('⚠️ Warning: Labels and stepValues length mismatch');
      return _buildEmptyChart();
    }

    // ✅ Calculate max Y value for chart scaling
    final double maxValue = widget.stepValues.isNotEmpty
        ? widget.stepValues.reduce((a, b) => a > b ? a : b)
        : 0;
    final double maxY = maxValue > 0 ? (maxValue * 1.2) : 1000.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range header
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0, left: 8.0),
            child: Text(
              widget.dateRange,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Bar chart
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final steps = widget.stepValues[groupIndex].toInt();
                      return BarTooltipItem(
                        '${widget.labels[groupIndex]}\n$steps steps',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == 0) {
                          return const SizedBox.shrink();
                        }
                        // Format labels based on view
                        String label = isWeekly
                            ? '${value.toInt()}'
                            : '${(value / 1000).toStringAsFixed(0)}k';
                        return Text(
                          label,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= widget.labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            widget.labels[index],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 5,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: Color(0xFFE0E0E0),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: _buildBarGroups(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Personal Record section
          _buildPersonalRecord(),

          const SizedBox(height: 16),

          // Legend
          _buildLegend(),
        ],
      ),
    );
  }

  /// 🟢 Build bar groups with correct target threshold
  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(
      widget.labels.length,
          (index) {
        final double currentSteps = widget.stepValues[index];
        final double barWidth = isWeekly ? 20 : 30;

        // ❌ EMPTY BAR (0 or negative steps)
        if (currentSteps <= 0) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: 0.1,
                color: Colors.grey[300],
                width: barWidth,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }

        // 🔴 ONLY RED BAR (steps <= target)
        if (currentSteps <= stepTarget) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: currentSteps,
                color: Colors.redAccent,
                width: barWidth,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }

        // 🔴🔵 STACKED BAR (RED + BLUE for steps > target)
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: currentSteps,
              color: Colors.transparent,
              width: barWidth,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
              rodStackItems: [
                // 🔴 RED: Steps towards goal (0 to target)
                BarChartRodStackItem(
                  0,
                  stepTarget,
                  Colors.redAccent,
                ),
                // 🔵 BLUE: Bonus steps above goal (target+)
                BarChartRodStackItem(
                  stepTarget,
                  currentSteps,
                  Colors.blueAccent,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// ✅ Build personal record section
  Widget _buildPersonalRecord() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Record',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.maxSteps > 0
                          ? 'Most Steps ${isWeekly ? "in a Day" : "in a Week"}: ${widget.maxSteps}'
                          : 'No steps recorded yet',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.maxSteps > 0 ? widget.maxStepsDate : 'Start tracking!',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🟢 Build legend with correct thresholds
  Widget _buildLegend() {
    final String redLabel = isWeekly
        ? 'Steps for Points (0-10k)'
        : 'Weekly Goal (0-70k)';
    final String blueLabel = isWeekly
        ? 'Bonus Steps (10k+)'
        : 'Bonus Steps (70k+)';

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(redLabel, Colors.redAccent),
          const SizedBox(width: 24),
          _buildLegendItem(blueLabel, Colors.blueAccent),
        ],
      ),
    );
  }

  /// Build individual legend item
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// ✅ Build empty chart placeholder
  Widget _buildEmptyChart() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Icon(Icons.bar_chart, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No data available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking your steps to see your progress!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
