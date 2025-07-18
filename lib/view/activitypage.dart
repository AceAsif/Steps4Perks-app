import 'package:flutter/material.dart';
import 'package:myapp/features/step_bar_chart.dart';
import 'package:myapp/services/database_service.dart';
import 'package:intl/intl.dart'; // ⬅️ Add this at the top

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

  @override
  void initState() {
    super.initState();
    _fetchWeeklyData();
  }

  Future<void> _fetchWeeklyData() async {
    try {
      final data = await _databaseService.getWeeklyStepData(); // { 'Mon': 5000, 'Tue': 8000, ... }
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Monday

      int maxSteps = 0;
      String maxStepsDateFormatted = '';

      Map<String, int> formattedData = {};
      for (int i = 0; i < 7; i++) {
        final date = startOfWeek.add(Duration(days: i));
        final dayLabel = DateFormat('E').format(date); // 'Mon', 'Tue', etc.
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
      });
    } catch (e) {
      debugPrint("❌ Failed to load weekly data: $e");
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                      ? StepsBarChart(
                          labels: _weeklyData.keys.toList(),
                          stepValues: _weeklyData.values.map((e) => e.toDouble()).toList(),
                          dateRange: 'Activity for last 7 days',
                          maxSteps: _maxSteps,
                          maxStepsDate: _maxStepsDate,
                        )
                      : const Center(child: Text('Monthly chart coming soon...')),
                ],
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
