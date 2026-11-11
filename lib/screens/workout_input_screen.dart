import 'package:flutter/material.dart';
import '../widgets/card.dart'as ui;
import '../../widgets/custom_button.dart';

class WorkoutInputScreen extends StatefulWidget {
  final Function(String, String) onAnalyze;
  final VoidCallback onBack;
  final Map<String, String> currentPlan;
  final String sport;

  const WorkoutInputScreen({
    super.key,
    required this.onAnalyze,
    required this.onBack,
    required this.currentPlan,
    required this.sport,
  });

  @override
  _WorkoutInputScreenState createState() => _WorkoutInputScreenState();
}

class _WorkoutInputScreenState extends State<WorkoutInputScreen> {
  late TextEditingController workoutController;

  @override
  void initState() {
    super.initState();
    workoutController = TextEditingController(
      text: widget.currentPlan.values.join('\n'),
    );
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
                const Text(
                  "Analyze Your Workout",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Enter your typical weekly workout plan.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: workoutController,
                  maxLines: 8,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade800,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade600),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.cyan),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: "✨ Analyze with AI",
                  onPressed: () {
                    widget.onAnalyze(workoutController.text, widget.sport);
                  },
                  icon: Icons.auto_awesome,
                  backgroundColor: Colors.purple.shade600,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: "Back",
                  onPressed: widget.onBack,
                  backgroundColor: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
