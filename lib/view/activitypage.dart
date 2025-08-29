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
  Map<String, int> _monthlyData = {};
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

  Future<void> _fetchMonthlyData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Get **daily** data for the current month
      final data = await _databaseService.getMonthlyStepData();

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Week buckets (some months show Week 5 depending on day spread)
      Map<String, int> weekData = {
        'Week 1': 0,
        'Week 2': 0,
        'Week 3': 0,
        'Week 4': 0,
        'Week 5': 0,
      };

      // Accumulate each day into its week-of-month bucket
      for (int i = 0; i < 31; i++) {
        final date = startOfMonth.add(Duration(days: i));
        if (date.month != now.month) break;

        // Week-of-month index: 0..4
        final weekOfMonth = ((date.day - 1) / 7).floor();
        final label = 'Week ${weekOfMonth + 1}';

        final dayLabel = DateFormat('d MMM').format(date); // must match DB service
        final steps = data[dayLabel] ?? 0;

        weekData[label] = (weekData[label] ?? 0) + steps;
      }

      // Remove Week 5 if unused (keep minimal visual noise)
      if ((weekData['Week 5'] ?? 0) == 0) {
        weekData.remove('Week 5');
      }

      // Personal record for monthly view = max weekly total
      int maxSteps = 0;
      String maxStepsWeek = '';
      weekData.forEach((label, total) {
        if (total > maxSteps) {
          maxSteps = total;
          maxStepsWeek = label;
        }
      });

      setState(() {
        _monthlyData = weekData;
        _maxSteps = maxSteps;
        _maxStepsDate = maxStepsWeek; // displayed as "Week X" in chart footer
        _isLoading = false;
        _lastUpdated = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monthly data refreshed!')),
        );
      }
    } catch (e) {
      debugPrint("❌ Failed to load monthly data: $e");
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
        onRefresh: selectedTabIndex == 0 ? _fetchWeeklyData : _fetchMonthlyData,
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
              else if (selectedTabIndex == 0)
                StepsBarChart(
                  labels: _weeklyData.keys.toList(),
                  stepValues: _weeklyData.values.map((e) => e.toDouble()).toList(),
                  dateRange: 'Activity for last 7 days',
                  maxSteps: _maxSteps,
                  maxStepsDate: _maxStepsDate,
                )
              else
                StepsBarChart(
                  labels: _monthlyData.keys.toList(),
                  stepValues: _monthlyData.values.map((e) => e.toDouble()).toList(),
                  dateRange: 'Activity for ${DateFormat('MMMM yyyy').format(DateTime.now())}',
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
          } else {
            _fetchMonthlyData();
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