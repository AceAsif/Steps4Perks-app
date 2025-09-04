import 'package:flutter/material.dart';
import 'package:myapp/features/step_bar_chart.dart';
import 'package:myapp/services/database_service.dart';
import 'package:intl/intl.dart';
import 'package:myapp/widgets/shimmer_loader.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/step_tracker.dart';

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

  VoidCallback? _trackerListener; // ✅ listen for live updates

  @override
  void initState() {
    super.initState();
    _fetchWeeklyData(showSnackbar: false);

    // ✅ Add StepTracker listener after first frame to avoid context issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tracker = Provider.of<StepTracker>(context, listen: false);
      _trackerListener = () {
        // Refresh the visible tab when steps change
        if (!mounted) return;
        if (selectedTabIndex == 0) {
          _fetchWeeklyData(showSnackbar: false);
        } else {
          _fetchMonthlyData();
        }
      };
      tracker.addListener(_trackerListener!);
    });
  }

  @override
  void dispose() {
    // ✅ Clean up listener
    if (_trackerListener != null) {
      final tracker = Provider.of<StepTracker>(context, listen: false);
      tracker.removeListener(_trackerListener!);
    }
    super.dispose();
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
      // ✅ Use server-side week-of-month aggregation as provided by DatabaseService
      final weekData = await _databaseService.getMonthlyStepData();

      // Compute max week
      int maxSteps = 0;
      String maxWeekLabel = '';
      for (final entry in weekData.entries) {
        if (entry.value > maxSteps) {
          maxSteps = entry.value;
          maxWeekLabel = entry.key; // e.g., "Week 3"
        }
      }

      setState(() {
        _monthlyData = weekData;        // e.g., {Week 1: 12000, ...}
        _maxSteps = maxSteps;
        _maxStepsDate = maxWeekLabel;   // show the week label under "Personal Record"
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
                    labels: _monthlyData.keys.toList(), // ["Week 1"..."Week 5"]
                    stepValues: _monthlyData.values.map((e) => e.toDouble()).toList(),
                    dateRange: 'Activity for ${DateFormat('MMMM yyyy').format(DateTime.now())}',
                    maxSteps: _maxSteps,
                    maxStepsDate: _maxStepsDate, // "Week X"
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
