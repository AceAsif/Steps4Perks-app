import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/view/homepage.dart';

class TutorialWrapper extends StatefulWidget {
  const TutorialWrapper({super.key});

  @override
  State<TutorialWrapper> createState() => _TutorialWrapperState();
}

class _TutorialWrapperState extends State<TutorialWrapper> {
  int _tutorialStep = 0;
  bool _showTutorial = false;

  final GlobalKey _stepGaugeKey = GlobalKey();
  final GlobalKey _dailyStreakKey = GlobalKey();
  final GlobalKey _pointsEarnedKey = GlobalKey();
  final GlobalKey _mockStepsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

    if (!onboardingComplete) {
      setState(() {
        _showTutorial = true;
      });
      await prefs.setBool('onboarding_complete', true);
    }
  }

  void _nextStep() {
    setState(() {
      if (_tutorialStep < 4) {
        _tutorialStep++;
      } else {
        _showTutorial = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The main content of your app (the homepage)
        HomePage(
          stepGaugeKey: _stepGaugeKey,
          dailyStreakKey: _dailyStreakKey,
          pointsEarnedKey: _pointsEarnedKey,
          mockStepsKey: _mockStepsKey,
        ),

        // The tutorial overlay
        if (_showTutorial)
          GestureDetector(
            onTap: _nextStep,
            child: Container(
              color: const Color.fromRGBO(0, 0, 0, 0.1), // Semi-transparent black
              child: _buildTutorialOverlay(context),
            ),
          ),
      ],
    );
  }

  Widget _buildTutorialOverlay(BuildContext context) {
    switch (_tutorialStep) {
      case 0:
        return _buildTextOverlay(
          context,
          'This is your step gauge. It shows how close you are to your daily goal of 10,000 steps!',
          _stepGaugeKey,
        );
      case 1:
        return _buildTextOverlay(
          context,
          'Here you can see your daily streak. Keep walking every day to build a long streak.',
          _dailyStreakKey,
        );
      case 2:
        return _buildTextOverlay(
          context,
          'These are the points you\'ve earned today. You can use them to claim rewards.',
          _pointsEarnedKey,
        );
      case 3:
        return _buildTextOverlay(
          context,
          'Use this button to add mock steps for testing purposes. It only works in debug mode.',
          _mockStepsKey,
        );
      case 4:
        return _buildTextOverlay(
          context,
          'You\'re all set! Tap anywhere to start your journey.',
          null,
        );
      default:
        return Container();
    }
  }

  Widget _buildTextOverlay(BuildContext context, String text, GlobalKey? targetKey) {
    final renderBox = targetKey?.currentContext?.findRenderObject() as RenderBox?;
    final position = renderBox?.localToGlobal(Offset.zero);
    final size = renderBox?.size;

    return Stack(
      children: [
        if (position != null && size != null)
          Positioned(
            left: position.dx,
            top: position.dy,
            child: Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 255, 255, 0.2), // Semi-transparent white
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.yellow, width: 2),
              ),
            ),
          ),

        Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.black, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
