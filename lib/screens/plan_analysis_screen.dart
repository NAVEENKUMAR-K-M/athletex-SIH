import 'package:flutter/material.dart';
import '../widgets/card.dart' as ui;
import '../../widgets/custom_button.dart';
import '../../services/gemini_api.dart';

class PlanAnalysisScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onComplete;
  final String analysisType;
  final String planInput;
  final String sport;

  const PlanAnalysisScreen({
    super.key,
    required this.onComplete,
    required this.analysisType,
    required this.planInput,
    required this.sport,
  });

  @override
  _PlanAnalysisScreenState createState() => _PlanAnalysisScreenState();
}

class _PlanAnalysisScreenState extends State<PlanAnalysisScreen> {
  bool loading = true;
  Map<String, dynamic>? analysisResult;

  @override
  void initState() {
    super.initState();
    _analyzePlan();
  }

  Future<void> _analyzePlan() async {
    final prompt = "Analyze my ${widget.analysisType} for my sport, ${widget.sport}: ${widget.planInput}";
    final result = await GeminiApi.callGeminiApi(prompt);
    
    if (mounted) {
      setState(() {
        analysisResult = result;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.analysisType == 'diet' ? 'Diet Analysis' : 'Workout Analysis';
    final accentColor = widget.analysisType == 'diet' ? Colors.green : Colors.purple;

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
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 24),
                if (loading) ...[
                  const Text(
                    "✨ AI is analyzing your plan...",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ] else if (analysisResult != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "AI Summary & Recommendations",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          analysisResult!['summary'] ?? '',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "New AI-Generated Plan",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: (analysisResult!['newPlan'] as Map).entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: "${entry.key[0].toUpperCase()}${entry.key.substring(1)}: ",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                TextSpan(
                                  text: entry.value,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: "Adopt This Plan",
                    onPressed: () {
                      widget.onComplete(analysisResult!['newPlan']);
                    },
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
