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
  int selectedTabIndex = 0;
  final DatabaseService _databaseService = DatabaseService();

  Map<String, int> _weeklyData = {};
  Map<String, int> _monthlyData = {};
  bool _isLoading = true;

  int _maxSteps = 0;
  String _maxStepsDate = '';
  DateTime? _lastUpdated;
  bool _hasError = false;

  VoidCallback? _trackerListener;

  @override
  void initState() {
    super.initState();
    _fetchWeeklyData(showSnackbar: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tracker = Provider.of<StepTracker>(context, listen: false);
      _trackerListener = () {
        if (!mounted) return;
        if (selectedTabIndex == 0) {
          _fetchWeeklyData(showSnackbar: false);
        } else {
          _fetchMonthlyData(showSnackbar: false);
        }
      };
      tracker.addListener(_trackerListener!);
    });
  }

  @override
  void dispose() {
    if (_trackerListener != null) {
      final tracker = Provider.of<StepTracker>(context, listen: false);
      tracker.removeListener(_trackerListener!);
    }
    super.dispose();
  }

  /// ✅ Fetch weekly data with proper error handling
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
        _maxStepsDate = maxStepsDateFormatted.isEmpty
            ? 'No steps recorded yet'
            : maxStepsDateFormatted;
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

      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load weekly data. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ✅ Fetch monthly data with empty data handling
  Future<void> _fetchMonthlyData({bool showSnackbar = true}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final weekData = await _databaseService.getMonthlyStepData();

      // ✅ Handle empty or null monthly data
      if (weekData.isEmpty || weekData.values.every((steps) => steps == 0)) {
        setState(() {
          _monthlyData = {
            'Week 1': 0,
            'Week 2': 0,
            'Week 3': 0,
            'Week 4': 0,
          };
          _maxSteps = 0;
          _maxStepsDate = 'No steps recorded yet';
          _isLoading = false;
          _lastUpdated = DateTime.now();
        });

        if (showSnackbar && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No monthly data available yet. Keep tracking!'),
            ),
          );
        }
        return;
      }

      // ✅ Calculate max week
      int maxSteps = 0;
      String maxWeekLabel = '';
      for (final entry in weekData.entries) {
        if (entry.value > maxSteps) {
          maxSteps = entry.value;
          maxWeekLabel = entry.key;
        }
      }

      setState(() {
        _monthlyData = weekData;
        _maxSteps = maxSteps;
        _maxStepsDate = maxWeekLabel.isEmpty ? 'No steps recorded yet' : maxWeekLabel;
        _isLoading = false;
        _lastUpdated = DateTime.now();
      });

      if (showSnackbar && mounted) {
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

      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load monthly data. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        onRefresh: selectedTabIndex == 0
            ? () => _fetchWeeklyData()
            : () => _fetchMonthlyData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Tab buttons
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

              // Content area
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: StepChartShimmer(),
                )
              else if (_hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 20.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load chart',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please check your internet connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (selectedTabIndex == 0) {
                            _fetchWeeklyData();
                          } else {
                            _fetchMonthlyData();
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
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

              // Last updated timestamp
              if (_lastUpdated != null && !_hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
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
