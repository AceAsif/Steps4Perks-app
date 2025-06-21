import 'package:flutter/material.dart';
import 'package:myapp/features/step_bar_chart.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({Key? key}) : super(key: key);

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
      body: Column(
        children: [
          // Tab Buttons
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 30.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                _buildTabButton("Weekly", 0, screenWidth),
                const SizedBox(width: 12),
                _buildTabButton("Monthly", 1, screenWidth),
              ],
            ),
          ),

          // Content Based on Selected Tab
          Expanded(
            child:
                selectedTabIndex == 0
                    // This one is for the weekly bar chart
                    ? StepsBarChart(
                      labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                      stepValues: [1900, 7200, 14200, 9500, 9400, 8200, 7500],
                    )
                    // This one is for the monthly bar chart
                    : StepsBarChart(
                      labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
                      stepValues: [5800, 6200, 7000, 8500, 9100],
                    )
          ),
        ],
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? Colors.black
                    : const Color.fromARGB(255, 230, 230, 230),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: screenWidth * 0.04,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
