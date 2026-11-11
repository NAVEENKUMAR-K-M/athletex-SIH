import 'package:flutter/material.dart';
import '../widgets/card.dart'as ui;
import '../../widgets/custom_button.dart';

class DietInputScreen extends StatefulWidget {
  final Function(String, String) onAnalyze;
  final VoidCallback onBack;
  final Map<String, String> currentPlan;
  final String sport;

  const DietInputScreen({
    super.key,
    required this.onAnalyze,
    required this.onBack,
    required this.currentPlan,
    required this.sport,
  });

  @override
  _DietInputScreenState createState() => _DietInputScreenState();
}

class _DietInputScreenState extends State<DietInputScreen> {
  late TextEditingController dietController;

  @override
  void initState() {
    super.initState();
    dietController = TextEditingController(
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
                  "Analyze Your Diet",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Enter your typical daily food intake below.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dietController,
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
                    widget.onAnalyze(dietController.text, widget.sport);
                  },
                  icon: Icons.auto_awesome,
                  backgroundColor: Colors.green.shade600,
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
