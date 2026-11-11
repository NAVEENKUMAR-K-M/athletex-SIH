import 'package:flutter/material.dart';
import '../widgets/card.dart'as ui;

class SportSelectionScreen extends StatelessWidget {
  final Function(String) onSelectSport;
  final VoidCallback onLogout;

  const SportSelectionScreen({
    super.key,
    required this.onSelectSport,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final sports = [
      {'name': "Weightlifting", 'icon': Icons.fitness_center, 'color': Colors.red},
      {'name': "Athletics", 'icon': Icons.directions_run, 'color': Colors.yellow},
      {'name': "Swimming", 'icon': Icons.pool, 'color': Colors.blue},
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
                  "Choose Your Sport",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Select your primary discipline.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ...sports.map((sport) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () => onSelectSport(sport['name'] as String),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            sport['icon'] as IconData,
                            size: 40,
                            color: sport['color'] as Color,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              sport['name'] as String,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onLogout,
                  child: const Text(
                    "Or log out",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
