import 'package:flutter/material.dart';
import '../widgets/card.dart'as ui;
import '../../widgets/custom_button.dart';

class HeightWeightInputScreen extends StatefulWidget {
  final Function(Map<String, String>) onComplete;
  final VoidCallback onBack;

  const HeightWeightInputScreen({
    super.key,
    required this.onComplete,
    required this.onBack,
  });

  @override
  _HeightWeightInputScreenState createState() => _HeightWeightInputScreenState();
}

class _HeightWeightInputScreenState extends State<HeightWeightInputScreen> {
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();

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
                  "Your Measurements",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Enter your current height and weight.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: heightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Height (cm)",
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: "e.g., 180",
                    hintStyle: TextStyle(color: Colors.grey.shade600),
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
                const SizedBox(height: 16),
                TextField(
                  controller: weightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Weight (kg)",
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: "e.g., 85",
                    hintStyle: TextStyle(color: Colors.grey.shade600),
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
                  text: "Submit",
                  onPressed: () {
                    widget.onComplete({
                      'height': heightController.text,
                      'weight': weightController.text,
                    });
                  },
                  icon: Icons.check_circle,
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
