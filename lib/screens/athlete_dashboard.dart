// lib/screens/athlete_dashboard.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/card.dart' as ui;
import '../../widgets/custom_button.dart';
import '../../widgets/progress_bar.dart';
import 'ml_analysis_screen.dart';
import 'assessment_selection_screen.dart';
import 'height_weight_input_screen.dart';
import 'camera_view_screen.dart';
import 'assessment_analysis_screen.dart';
import 'diet_input_screen.dart';
import 'workout_input_screen.dart';
import 'plan_analysis_screen.dart';
import 'certificate_verification_screen.dart';
import '../models/leaderboard_data.dart';

// New imports
import 'package:provider/provider.dart';
import '../models/athlete_profiles.dart'; // MockAthleteProfiles (adjust path if needed)
import '../services/shared_data_service.dart'; // SharedDataService & models

class AthleteDashboard extends StatefulWidget {
  final VoidCallback onLogout;
  final Map<String, dynamic> athleteData;

  const AthleteDashboard({
    super.key,
    required this.onLogout,
    required this.athleteData,
  });

  @override
  _AthleteDashboardState createState() => _AthleteDashboardState();
}

class _AthleteDashboardState extends State<AthleteDashboard> {
  String view = 'dashboard';
  String? selectedTest;
  Map<String, dynamic> planToAnalyze = {'type': '', 'data': ''};

  @override
  void initState() {
    super.initState();

    // Ensure the profile exists in the mock (and thus mirrored into SharedDataService).
    final sport = widget.athleteData['sport']?.toString() ?? widget.athleteData['name']?.toString() ?? 'unknown';
    MockAthleteProfiles.getOrCreate(sport);
  }

  // Helpers to fetch the current profile map. Prefer SharedDataService (live),
  // fall back to MockAthleteProfiles if needed.
  Map<String, dynamic> _getCurrentProfile(BuildContext context) {
    try {
      final shared = Provider.of<SharedDataService>(context);
      final id = (widget.athleteData['id']?.toString()) ?? (widget.athleteData['sport']?.toString());
      if (id != null) {
        final athleteModel = shared.athleteById(id);
        if (athleteModel != null) {
          // athleteModel.metadata is the original map we stored earlier
          return Map<String, dynamic>.from(athleteModel.metadata);
        }
      }
    } catch (_) {
      // provider not found or mapping failed — we'll fallback below
    }

    // Fallback: use the mock profiles keyed by sport
    final sport = widget.athleteData['sport']?.toString() ?? widget.athleteData['name']?.toString() ?? 'unknown';
    return MockAthleteProfiles.getOrCreate(sport);
  }

  void handleDietAnalysisComplete(Map<String, dynamic> newDietPlan) {
    // Use MockAthleteProfiles to keep mock and shared service consistent
    final sport = widget.athleteData['sport']?.toString() ?? 'unknown';
    final profile = MockAthleteProfiles.getOrCreate(sport);
    profile['dietPlan'] = newDietPlan;
    // Mirror into SharedDataService via MockAthleteProfiles or directly:
    try {
      final athlete = MockAthleteProfiles.getOrCreate(sport);
      SharedDataService().addOrUpdateAthlete(SharedDataService().athleteById(athlete['id']?.toString() ?? sport) ?? Athlete(
        id: athlete['id']?.toString() ?? sport,
        name: athlete['name']?.toString() ?? sport,
        metadata: Map<String, dynamic>.from(athlete),
      ));
    } catch (_) {}
    setState(() {
      view = 'dashboard';
    });
  }

  void handleWorkoutAnalysisComplete(Map<String, dynamic> newWorkoutPlan) {
    final sport = widget.athleteData['sport']?.toString() ?? 'unknown';
    final profile = MockAthleteProfiles.getOrCreate(sport);
    profile['workoutPlan'] = newWorkoutPlan;
    try {
      final athlete = MockAthleteProfiles.getOrCreate(sport);
      SharedDataService().addOrUpdateAthlete(SharedDataService().athleteById(athlete['id']?.toString() ?? sport) ?? Athlete(
        id: athlete['id']?.toString() ?? sport,
        name: athlete['name']?.toString() ?? sport,
        metadata: Map<String, dynamic>.from(athlete),
      ));
    } catch (_) {}
    setState(() {
      view = 'dashboard';
    });
  }

  void handleCertificateVerificationComplete(Map<String, dynamic> newData) {
    final sport = widget.athleteData['sport']?.toString() ?? 'unknown';
    final profile = MockAthleteProfiles.getOrCreate(sport);
    profile['fitnessCertificate'] = newData;
    try {
      final athlete = MockAthleteProfiles.getOrCreate(sport);
      SharedDataService().addOrUpdateAthlete(SharedDataService().athleteById(athlete['id']?.toString() ?? sport) ?? Athlete(
        id: athlete['id']?.toString() ?? sport,
        name: athlete['name']?.toString() ?? sport,
        metadata: Map<String, dynamic>.from(athlete),
      ));
    } catch (_) {}
    setState(() {
      view = 'dashboard';
    });
  }

  void handleHeightWeightComplete(Map<String, String> data) {
    final sport = widget.athleteData['sport']?.toString() ?? 'unknown';
    // Update via mock profile (which mirrors into SharedDataService)
    MockAthleteProfiles.updateAssessment(sport, 'height', "${data['height']} cm");
    MockAthleteProfiles.updateAssessment(sport, 'weight', "${data['weight']} kg");
    setState(() {
      view = 'dashboard';
    });
  }

  void startDietAnalysis(Map<String, dynamic> currentPlan, String sport) {
    setState(() {
      planToAnalyze = {
        'type': 'diet',
        'data': currentPlan.values.join('\n'),
        'sport': sport
      };
      view = 'planAnalysis';
    });
  }

  void startWorkoutAnalysis(Map<String, dynamic> currentPlan, String sport) {
    setState(() {
      planToAnalyze = {
        'type': 'workout',
        'data': currentPlan.values.join('\n'),
        'sport': sport
      };
      view = 'planAnalysis';
    });
  }

  double _toDoubleSafe(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final parsed = double.tryParse(val);
      if (parsed != null) return parsed;
      // strip non-digit
      final cleaned = val.replaceAll(RegExp(r'[^0-9\.\-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  double _parseScore(dynamic score) {
    // score may be '-' or string; handle safely
    return _toDoubleSafe(score);
  }

  Widget _buildDashboard(Map<String, dynamic> currentAthleteData) {
    // Defensive getters
    final xp = _toDoubleSafe(currentAthleteData['xp']);
    final nextXp = _toDoubleSafe(currentAthleteData['nextLevelXp']);
    final level = currentAthleteData['level'] ?? 1;
    final perfHistory = (currentAthleteData['performanceHistory'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome, ${currentAthleteData['name']}",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    currentAthleteData['sport'],
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: widget.onLogout,
                child: const Text(
                  "Logout",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Action Buttons
          ui.Card(
            child: Column(
              children: [
                const Text(
                  "Start a New Session",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: "Record",
                        onPressed: () {
                          // Previously this set view='analysis' (which immediately shows analysis page).
                          // To ensure camera is only accessed when recording starts, we navigate to camera view
                          // where the camera will be initialized only when the user taps Start Recording.
                          setState(() {
                            view = 'cameraView';
                          });
                        },
                        icon: Icons.upload_file,
                        backgroundColor: Colors.blue.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: "Assess",
                        onPressed: () {
                          setState(() {
                            view = 'assessmentSelection';
                          });
                        },
                        icon: Icons.assignment,
                        backgroundColor: Colors.purple.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Athlete Profile Card
          ui.Card(
            child: Row(
              children: [
                const Icon(
                  Icons.person,
                  size: 32,
                  color: Colors.cyan,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Level $level",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyan,
                            ),
                          ),
                          Text(
                            "${xp.toInt()} / ${nextXp.toInt()} XP",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ProgressBar(
                        value: xp,
                        max: nextXp <= 0 ? 1.0 : nextXp,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Certificate Status
          _buildCertificateStatus(currentAthleteData['fitnessCertificate'] ?? {'status': '-'}),
          const SizedBox(height: 16),

          // Performance History Chart
          ui.Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart),
                    SizedBox(width: 8),
                    Text(
                      "Performance History",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 150,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < perfHistory.length) {
                                return Text(
                                  perfHistory[index]['date']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: perfHistory
                              .asMap()
                              .entries
                              .map((entry) => FlSpot(entry.key.toDouble(), _parseScore(entry.value['score'])))
                              .toList(),
                          isCurved: true,
                          color: Colors.cyan,
                          barWidth: 2,
                          dotData: FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Recent Assessments
          ui.Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment),
                    SizedBox(width: 8),
                    Text(
                      "Recent Assessments",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: (currentAthleteData['assessments'] as Map).length,
                  itemBuilder: (context, index) {
                    final assessmentName = (currentAthleteData['assessments'] as Map).keys.elementAt(index);
                    final assessment = currentAthleteData['assessments'][assessmentName] as Map<String, dynamic>? ?? {};

                    IconData icon;
                    switch (assessmentName) {
                      case 'height':
                        icon = Icons.straighten;
                        break;
                      case 'weight':
                        icon = Icons.monitor_weight;
                        break;
                      case 'verticalJump':
                        icon = Icons.arrow_upward;
                        break;
                      case 'shuttleRun':
                        icon = Icons.swap_horiz;
                        break;
                      case 'sitUps':
                        icon = Icons.favorite;
                        break;
                      case 'enduranceRun':
                        icon = Icons.timer;
                        break;
                      default:
                        icon = Icons.help_outline;
                    }

                    final value = assessment['value']?.toString() ?? '-';
                    final unit = assessment['unit']?.toString() ?? '';

                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                icon,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  assessmentName[0].toUpperCase() + assessmentName.substring(1),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            unit.isNotEmpty ? "$value $unit" : value,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Achievements
          ui.Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emoji_events),
                    SizedBox(width: 8),
                    Text(
                      "Achievements",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: (currentAthleteData['achievements'] as List).length,
                  itemBuilder: (context, index) {
                    final achievement = currentAthleteData['achievements'][index];
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            achievement['icon'],
                            size: 24,
                            color: achievement['color'],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              achievement['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Leaderboard
          ui.Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.leaderboard),
                    SizedBox(width: 8),
                    Text(
                      "Leaderboard",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  children: (MockLeaderboardData.data.take(4).map((player) {
                    final isCurrentUser = player['isCurrentUser'] ?? false;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrentUser ? Colors.blue.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 20,
                                child: Text(
                                  "${player['rank']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                player['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "${player['xp']} XP",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.cyan,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  })).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Diet Plan
          ui.Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.restaurant),
                        SizedBox(width: 8),
                        Text(
                          "Diet Plan",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          view = 'dietInput';
                        });
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 14),
                          SizedBox(width: 4),
                          Text(
                            "Analyze",
                            style: TextStyle(
                              color: Colors.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlanItem("Breakfast:", currentAthleteData['dietPlan']?['breakfast']?.toString() ?? '-'),
                    const SizedBox(height: 8),
                    _buildPlanItem("Lunch:", currentAthleteData['dietPlan']?['lunch']?.toString() ?? '-'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Workout Plan
          ui.Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.fitness_center),
                        SizedBox(width: 8),
                        Text(
                          "Workout Plan",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          view = 'workoutInput';
                        });
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 14),
                          SizedBox(width: 4),
                          Text(
                            "Analyze",
                            style: TextStyle(
                              color: Colors.cyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlanItem("Monday:", currentAthleteData['workoutPlan']?['monday']?.toString() ?? '-'),
                    const SizedBox(height: 8),
                    _buildPlanItem("Tuesday:", currentAthleteData['workoutPlan']?['tuesday']?.toString() ?? '-'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPlanItem(String label, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          TextSpan(
            text: " $value",
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateStatus(Map<String, dynamic> cert) {
    Widget statusInfo;
    Widget button;

    if (cert['status'] == 'Verified') {
      statusInfo = Row(
        children: const [
          Icon(Icons.verified, color: Colors.green, size: 18),
          SizedBox(width: 4),
          Text("Verified"),
        ],
      );
      button = CustomButton(
        text: "Upload New",
        onPressed: () {
          setState(() {
            view = 'certificateVerification';
          });
        },
        backgroundColor: Colors.grey.shade600,
      );
    } else if (cert['status'] == 'Pending') {
      statusInfo = Row(
        children: const [
          Icon(Icons.hourglass_top, color: Colors.yellow, size: 18),
          SizedBox(width: 4),
          Text("Pending"),
        ],
      );
      button = CustomButton(
        text: "Re-upload",
        onPressed: () {
          setState(() {
            view = 'certificateVerification';
          });
        },
        backgroundColor: Colors.grey.shade600,
      );
    } else {
      statusInfo = Row(
        children: const [
          Icon(Icons.warning, color: Colors.red, size: 18),
          SizedBox(width: 4),
          Text("Not Uploaded"),
        ],
      );
      button = CustomButton(
        text: "Upload Now",
        onPressed: () {
          setState(() {
            view = 'certificateVerification';
          });
        },
        backgroundColor: Colors.cyan.shade600,
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.verified_user),
              SizedBox(width: 8),
              Text(
                "Fitness Certificate",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DefaultTextStyle(
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            child: statusInfo,
          ),
          const SizedBox(height: 8),
          Text(
            cert['status'] == 'Verified' ? "Dr. ${cert['doctorName']}" : 'A verified certificate is required.',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          button,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentAthleteData = _getCurrentProfile(context);

    switch (view) {
      case 'analysis':
        return MLAnalysisScreen(onBack: () {
          setState(() {
            view = 'dashboard';
          });
        });
      case 'assessmentSelection':
        return AssessmentSelectionScreen(
          onSelectTest: (test) {
            setState(() {
              selectedTest = test;
              if (test == 'Height & Weight') {
                view = 'heightWeightInput';
              } else {
                view = 'cameraView';
              }
            });
          },
          onBack: () {
            setState(() {
              view = 'dashboard';
            });
          },
        );
      case 'cameraView':
        return CameraViewScreen(
          testName: selectedTest ?? '',
          onStartAnalysis: () {
            // CameraViewScreen should call this callback when recording finishes and analysis should start.
            setState(() {
              view = 'assessmentAnalysis';
            });
          },
          onBack: () {
            setState(() {
              view = 'assessmentSelection';
            });
          },
        );
      case 'heightWeightInput':
        return HeightWeightInputScreen(
          onComplete: (data) {
            handleHeightWeightComplete(data);
          },
          onBack: () {
            setState(() {
              view = 'dashboard';
            });
          },
        );
      case 'assessmentAnalysis':
        return AssessmentAnalysisScreen(
          testName: selectedTest ?? '',
          onComplete: () {
            setState(() {
              view = 'dashboard';
            });
          },
        );
      case 'dietInput':
        return DietInputScreen(
          onAnalyze: (dietInput, sport) {
            startDietAnalysis(currentAthleteData['dietPlan'] ?? {}, sport);
          },
          onBack: () {
            setState(() {
              view = 'dashboard';
            });
          },
          currentPlan: currentAthleteData['dietPlan'] ?? {},
          sport: currentAthleteData['sport'] ?? widget.athleteData['sport'] ?? '',
        );
      case 'workoutInput':
        return WorkoutInputScreen(
          onAnalyze: (workoutInput, sport) {
            startWorkoutAnalysis(currentAthleteData['workoutPlan'] ?? {}, sport);
          },
          onBack: () {
            setState(() {
              view = 'dashboard';
            });
          },
          currentPlan: currentAthleteData['workoutPlan'] ?? {},
          sport: currentAthleteData['sport'] ?? widget.athleteData['sport'] ?? '',
        );
      case 'planAnalysis':
        return PlanAnalysisScreen(
          onComplete: (newPlan) {
            if (planToAnalyze['type'] == 'diet') {
              handleDietAnalysisComplete(newPlan);
            } else {
              handleWorkoutAnalysisComplete(newPlan);
            }
          },
          analysisType: planToAnalyze['type'],
          planInput: planToAnalyze['data'],
          sport: planToAnalyze['sport'],
        );
      case 'certificateVerification':
        return CertificateVerificationScreen(
          onComplete: (newData) {
            handleCertificateVerificationComplete(newData);
          },
        );
      default:
        return _buildDashboard(currentAthleteData);
    }
  }
}
