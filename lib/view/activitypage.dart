import 'package:flutter/material.dart';
import 'package:myapp/features/step_bar_chart.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  int selectedTabIndex = 0; // 0 = Weekly, 1 = Monthly

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
      body: SingleChildScrollView(
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
            // Chart and Data
            selectedTabIndex == 0
                ? StepsBarChart(
                    labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                    stepValues: [1900, 7200, 14200, 9500, 9400, 8200, 7500],
                    dateRange: 'Activity for 10 - 16 June 2025',
                  )
                : StepsBarChart(
                    labels: ['1-7', '8-14', '15-21', '22-28', '29-31'],
                    stepValues: [5800, 6200, 7000, 8500, 9100],
                    dateRange: 'Activity for June 2025',
                  ),
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
