import 'package:flutter/material.dart';
import 'package:myapp/features/step_bar_chart.dart';
import 'package:myapp/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:myapp/widgets/shimmer_loader.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  int selectedTabIndex = 0; // 0 = Weekly, 1 = Monthly
  final DatabaseService _databaseService = DatabaseService();

  Map<String, int> _weeklyData = {};
  bool _isLoading = true;

  int _maxSteps = 0;
  String _maxStepsDate = '';
  DateTime? _lastUpdated;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchWeeklyData(showSnackbar: false);
  }

  Future<void> _fetchWeeklyData({bool showSnackbar = true}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final data = await _databaseService.getWeeklyStepData();
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

      int maxSteps = 0;
      String maxStepsDateFormatted = '';
      Map<String, int> formattedData = {};

      for (int i = 0; i < 7; i++) {
        final date = startOfWeek.add(Duration(days: i));
        final dayLabel = DateFormat('E').format(date);
        final steps = data[dayLabel] ?? 0;

        formattedData[dayLabel] = steps;

        if (steps > maxSteps) {
          maxSteps = steps;
          maxStepsDateFormatted = DateFormat('d MMM yyyy (E)').format(date);
        }
      }

      setState(() {
        _weeklyData = formattedData;
        _maxSteps = maxSteps;
        _maxStepsDate = maxStepsDateFormatted;
        _isLoading = false;
        _lastUpdated = DateTime.now();
      });

      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weekly data refreshed!')),
        );
      }
    } catch (e) {
      debugPrint("❌ Failed to load weekly data: $e");
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22.0),
          child: Text('Activity'),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchWeeklyData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 12.0),
                child: Row(
                  children: [
                    _buildTabButton("Weekly", 0, screenWidth),
                    const SizedBox(width: 12),
                    _buildTabButton("Monthly", 1, screenWidth),
                  ],
                ),
              ),
              selectedTabIndex == 0
                  ? Column(
                      children: [
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                            child: StepChartShimmer(),
                          )
                        else if (_hasError)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 50.0),
                            child: Text(
                              'Failed to load chart. Please try again later.',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          )
                        else
                          StepsBarChart(
                            labels: _weeklyData.keys.toList(),
                            stepValues: _weeklyData.values.map((e) => e.toDouble()).toList(),
                            dateRange: 'Activity for last 7 days',
                            maxSteps: _maxSteps,
                            maxStepsDate: _maxStepsDate,
                          ),
                        if (_lastUpdated != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Text(
                              'Last updated: ${DateFormat('d MMM yyyy, h:mm a').format(_lastUpdated!)}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ),
                      ],
                    )
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 50.0),
                        child: Text('Monthly chart coming soon...'),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index, double screenWidth) {
    final isSelected = selectedTabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTabIndex = index;
          });

          if (index == 0) {
            _fetchWeeklyData();
          }

          if (index == 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Monthly data not available yet.')),
            );
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: screenWidth * 0.025),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : const Color(0xFFE6E6E6),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: screenWidth * 0.04,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
