import 'package:flutter/material.dart';
import '../widgets/card.dart'as ui;
import '../../widgets/custom_button.dart';
import '../../widgets/progress_bar.dart';

class AssessmentAnalysisScreen extends StatefulWidget {
  final String testName;
  final VoidCallback onComplete;

  const AssessmentAnalysisScreen({
    super.key,
    required this.testName,
    required this.onComplete,
  });

  @override
  _AssessmentAnalysisScreenState createState() => _AssessmentAnalysisScreenState();
}

class _AssessmentAnalysisScreenState extends State<AssessmentAnalysisScreen> {
  double progress = 0;
  Map<String, dynamic>? result;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  void _startAnalysis() {
    const interval = Duration(milliseconds: 150);
    Future.delayed(interval, () {
      if (mounted) {
        setState(() {
          progress += 10;
          if (progress >= 100) {
            result = _getMockResult(widget.testName);
          }
        });

        if (progress < 100) {
          _startAnalysis();
        }
      }
    });
  }

  Map<String, dynamic> _getMockResult(String test) {
    final mockResults = {
      'Vertical Jump': {'value': '32.5 inches', 'xp': 25},
      'Shuttle Run': {'value': '4.75 s', 'xp': 30},
      'Sit-ups': {'value': '58 reps/min', 'xp': 20},
      'Endurance Run': {'value': '10:15 (2.4km)', 'xp': 50}
    };
    
    return mockResults[test] ?? {'value': 'N/A', 'xp': 0};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ui.Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Analyzing: ${widget.testName}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                if (result == null) ...[
                  const Text(
                    "Processing results...",
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProgressBar(value: progress, max: 100, color: Colors.purple),
                ] else ...[
                  const Text(
                    "Assessment Complete",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Result",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          result!['value'],
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.yellow.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.trending_up, color: Colors.yellow, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          "XP Gained:",
                          style: TextStyle(
                            color: Colors.yellow,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "+${result!['xp']}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.yellow,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: "Save & Return",
                    onPressed: widget.onComplete,
                    icon: Icons.check_circle,
                    backgroundColor: Colors.blue.shade600,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
