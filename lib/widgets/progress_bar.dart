import 'package:flutter/material.dart';

class ProgressBar extends StatelessWidget {
  final double value;
  final double max;
  final Color? color;

  const ProgressBar({
    super.key,
    required this.value,
    required this.max,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Colors.grey.shade700,
          color: color ?? Colors.cyan,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Text(
          '${(percentage * 100).toInt()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
