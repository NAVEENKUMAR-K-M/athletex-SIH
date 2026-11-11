import 'package:flutter/material.dart';
import '../widgets/card.dart'as ui;
import '../../widgets/custom_button.dart';

class AssessmentSelectionScreen extends StatelessWidget {
  final Function(String) onSelectTest;
  final VoidCallback onBack;

  const AssessmentSelectionScreen({
    super.key,
    required this.onSelectTest,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final tests = [
      {'name': 'Height & Weight', 'icon': Icons.straighten},
      {'name': 'Vertical Jump', 'icon': Icons.arrow_upward},
      {'name': 'Shuttle Run', 'icon': Icons.swap_horiz},
      {'name': 'Sit-ups', 'icon': Icons.favorite},
      {'name': 'Endurance Run', 'icon': Icons.timer},
    ];

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
                  "Fitness Assessment",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Choose a test to begin.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: tests.length,
                  itemBuilder: (context, index) {
                    final test = tests[index];
                    return InkWell(
                      onTap: () => onSelectTest(test['name'] as String),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              test['icon'] as IconData,
                              size: 32,
                              color: Colors.cyan,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              test['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: "Back to Dashboard",
                  onPressed: onBack,
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
