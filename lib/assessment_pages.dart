// lib/assessment_pages.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ml_service.dart';
import 'utils.dart';
import 'package:camera/camera.dart';

// New imports
import 'services/shared_data_service.dart';
import 'models/athlete_profiles.dart';

class VerticalJumpPage extends StatefulWidget {
  const VerticalJumpPage({super.key});

  @override
  _VerticalJumpPageState createState() => _VerticalJumpPageState();
}

class _VerticalJumpPageState extends State<VerticalJumpPage> {
  bool running = false;
  double baselineHipY = 0;
  bool baselineSet = false;
  int jumpStartFrame = 0;
  int jumpEndFrame = 0;
  int frameCounter = 0;
  double lastHipY = 0;
  double jumpHeightMeters = 0.0;
  int fps = 30; // set correct fps according to camera / device

  // Helper to determine athlete id (best-effort). Replace with real wiring if available.
  String _getAthleteIdFallback() {
    final shared = SharedDataService();
    final athletes = shared.athletes;
    if (athletes.isNotEmpty) return athletes.first.id;
    return 'unknown-athlete';
  }

  // Central helper to push an assessment into SharedDataService and MockAthleteProfiles.
  void _pushAssessment(String type, dynamic value, {String? unit}) {
    final athleteId = _getAthleteIdFallback();
    final id = '$athleteId-$type-${DateTime.now().millisecondsSinceEpoch}';
    final assessment = Assessment(
      id: id,
      athleteId: athleteId,
      type: type,
      timestamp: DateTime.now(),
      metrics: {
        'value': value,
        if (unit != null) 'unit': unit,
        'from': 'ml',
      },
    );

    // add to shared service
    try {
      SharedDataService().addAssessment(assessment);
    } catch (_) {}

    // Mirror into MockAthleteProfiles if sport-keyed profile exists.
    try {
      // If SharedDataService athlete metadata contains sport, use it; otherwise skip
      final athlete = SharedDataService().athleteById(athleteId);
      final sport = athlete?.metadata['sport']?.toString() ?? athleteId;
      // update mock profile for backward compatibility
      MockAthleteProfiles.updateAssessment(sport, type, value.toString(), unit: unit);
    } catch (_) {}
  }

  void onPose(PoseResult res) {
    frameCounter++;
    final hip = (res.leftHip ?? res.rightHip);
    if (hip == null) return;
    final hipY = hip.y;
    lastHipY = hipY;

    if (!baselineSet) {
      baselineHipY = baselineHipY == 0 ? hipY : (baselineHipY * 0.95 + hipY * 0.05);
    }
    // set baseline after ~1 sec
    if (!baselineSet && frameCounter > fps * 1) {
      baselineSet = true;
    }

    // detect takeoff (hip y rises up -> y decreases)
    if (baselineSet && jumpStartFrame == 0 && baselineHipY - hipY > 20) {
      jumpStartFrame = frameCounter;
    }
    // detect landing: hipY returns near baseline
    if (jumpStartFrame != 0 &&
        jumpEndFrame == 0 &&
        (hipY - baselineHipY).abs() < 12 &&
        frameCounter - jumpStartFrame > 3) {
      jumpEndFrame = frameCounter;
      int frames = jumpEndFrame - jumpStartFrame;
      double t = frames / fps; // seconds
      double g = 9.80665;
      jumpHeightMeters = 0.5 * g * pow(t / 2.0, 2);

      // update MLService metric (keep existing behavior)
      try {
        context.read<MLService>().testMetrics['jumpHeight'] = jumpHeightMeters;
      } catch (_) {}

      // push into shared service
      _pushAssessment('verticalJump', jumpHeightMeters, unit: 'm');

      setState(() {});
    }
  }

  @override
  void dispose() {
    // stop ML stream if running
    try {
      final ml = Provider.of<MLService>(context, listen: false);
      ml.stopImageStream();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ml = Provider.of<MLService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Vertical Jump')),
      body: Column(
        children: [
          const Expanded(child: CameraPreviewWidget()),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text('Baseline set: $baselineSet'),
                Text('Jump height (m): ${jumpHeightMeters.toStringAsFixed(2)}'),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          ml.resetTest('vertical_jump'); // 🔄 reset metrics
                          await ml.loadModel();
                          await ml.startImageStream(onPose);
                          setState(() => running = true);
                        } catch (e) {
                          debugPrint('Error starting vertical jump: $e');
                        }
                      },
                      child: const Text('Start'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await ml.stopImageStream();
                          setState(() => running = false);
                        } catch (_) {}
                      },
                      child: const Text('Stop'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        baselineSet = false;
                        baselineHipY = 0;
                        jumpStartFrame = 0;
                        jumpEndFrame = 0;
                        frameCounter = 0;
                        jumpHeightMeters = 0;
                        // optionally clear last metric in MLService
                        try {
                          context.read<MLService>().testMetrics['jumpHeight'] = 0;
                        } catch (_) {}
                        setState(() {});
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class ShuttleRunPage extends StatefulWidget {
  const ShuttleRunPage({super.key});

  @override
  _ShuttleRunPageState createState() => _ShuttleRunPageState();
}

class _ShuttleRunPageState extends State<ShuttleRunPage> {
  double? leftX, rightX;
  int laps = 0;
  double lastX = 0;
  bool movingRight = true;

  String _getAthleteIdFallback() {
    final shared = SharedDataService();
    final athletes = shared.athletes;
    if (athletes.isNotEmpty) return athletes.first.id;
    return 'unknown-athlete';
  }

  void _pushLapMetric() {
    final athleteId = _getAthleteIdFallback();
    // store in MLService
    try {
      context.read<MLService>().testMetrics['laps'] = laps;
    } catch (_) {}

    // push into shared service as an assessment metric
    final id = '$athleteId-shuttleRun-${DateTime.now().millisecondsSinceEpoch}';
    final assessment = Assessment(
      id: id,
      athleteId: athleteId,
      type: 'shuttleRun',
      timestamp: DateTime.now(),
      metrics: {'laps': laps},
    );
    try {
      SharedDataService().addAssessment(assessment);
      final athlete = SharedDataService().athleteById(athleteId);
      final sport = athlete?.metadata['sport']?.toString() ?? athleteId;
      MockAthleteProfiles.updateAssessment(sport, 'shuttleRun', laps.toString());
    } catch (_) {}
  }

  void onPose(PoseResult res) {
    final hip = res.leftHip ?? res.rightHip;
    if (hip == null) return;
    final x = hip.x;
    if (leftX == null || rightX == null) return;
    if (lastX == 0) lastX = x;

    // crossing detection
    if (movingRight && (x >= rightX! - 10)) {
      movingRight = false;
      laps++;
      _pushLapMetric();
      setState(() {});
    } else if (!movingRight && (x <= leftX! + 10)) {
      movingRight = true;
      laps++;
      _pushLapMetric();
      setState(() {});
    }
    lastX = x;
  }

  @override
  void dispose() {
    try {
      context.read<MLService>().stopImageStream();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ml = Provider.of<MLService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Shuttle Run')),
      body: Column(
        children: [
          const Expanded(child: CameraPreviewWidget()),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Text('Calibrate two cones/sides with buttons'),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        final res = ml.latestResult;
                        if (res != null) {
                          final hip = res.leftHip ?? res.rightHip;
                          if (hip != null) leftX = hip.x;
                          setState(() {});
                        }
                      },
                      child: const Text('Set Left'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final res = ml.latestResult;
                        if (res != null) {
                          final hip = res.leftHip ?? res.rightHip;
                          if (hip != null) rightX = hip.x;
                          setState(() {});
                        }
                      },
                      child: const Text('Set Right'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('LeftX: ${leftX?.toStringAsFixed(1) ?? "-"}  RightX: ${rightX?.toStringAsFixed(1) ?? "-"}'),
                const SizedBox(height: 8),
                Text('Laps (counts): $laps'),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          ml.resetTest('shuttle_run'); // 🔄 reset metrics
                          await ml.loadModel();
                          await ml.startImageStream(onPose);
                        } catch (e) {
                          debugPrint('Error starting shuttle run: $e');
                        }
                      },
                      child: const Text('Start'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await ml.stopImageStream();
                        } catch (_) {}
                      },
                      child: const Text('Stop'),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class SitUpsPage extends StatefulWidget {
  const SitUpsPage({super.key});
  @override
  SitUpsPageState createState() => SitUpsPageState();
}

class SitUpsPageState extends State<SitUpsPage> {
  int reps = 0;
  bool up = false;
  double upThreshold = 40; // angle degrees
  double downThreshold = 20;

  String _getAthleteIdFallback() {
    final shared = SharedDataService();
    final athletes = shared.athletes;
    if (athletes.isNotEmpty) return athletes.first.id;
    return 'unknown-athlete';
  }

  void _pushRepsMetric() {
    final athleteId = _getAthleteIdFallback();
    try {
      context.read<MLService>().testMetrics['reps'] = reps;
    } catch (_) {}

    final id = '$athleteId-situps-${DateTime.now().millisecondsSinceEpoch}';
    final assessment = Assessment(
      id: id,
      athleteId: athleteId,
      type: 'sitUps',
      timestamp: DateTime.now(),
      metrics: {'reps': reps},
    );
    try {
      SharedDataService().addAssessment(assessment);
      final athlete = SharedDataService().athleteById(athleteId);
      final sport = athlete?.metadata['sport']?.toString() ?? athleteId;
      MockAthleteProfiles.updateAssessment(sport, 'sitUps', reps.toString(), unit: 'reps');
    } catch (_) {}
  }

  void onPose(PoseResult res) {
    final angle = res.trunkAngle().abs();
    if (!up && angle > upThreshold) {
      up = true;
    }
    if (up && angle < downThreshold) {
      reps++;
      up = false;
      // 💾 update reps metric
      _pushRepsMetric();
      setState(() {});
    }
  }

  @override
  void dispose() {
    try {
      context.read<MLService>().stopImageStream();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ml = Provider.of<MLService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sit Ups')),
      body: Column(
        children: [
          const Expanded(child: CameraPreviewWidget()),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text('Reps: $reps'),
                Row(children: [
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        ml.resetTest('situps'); // 🔄 reset metrics
                        await ml.loadModel();
                        await ml.startImageStream(onPose);
                      } catch (e) {
                        debugPrint('Error starting situps: $e');
                      }
                    },
                    child: const Text('Start'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await ml.stopImageStream();
                      } catch (_) {}
                    },
                    child: const Text('Stop'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      reps = 0;
                      // also reset shared metric if you want it cleared on UI reset
                      try {
                        context.read<MLService>().testMetrics['reps'] = 0;
                      } catch (_) {}
                      setState(() {});
                    },
                    child: const Text('Reset'),
                  ),
                ])
              ],
            ),
          )
        ],
      ),
    );
  }
}

class EnduranceRunPage extends StatefulWidget {
  const EnduranceRunPage({super.key});

  @override
  _EnduranceRunPageState createState() => _EnduranceRunPageState();
}

class _EnduranceRunPageState extends State<EnduranceRunPage> {
  int stepCount = 0;
  int frame = 0;
  int fps = 30;
  double cadence = 0.0;

  String _getAthleteIdFallback() {
    final shared = SharedDataService();
    final athletes = shared.athletes;
    if (athletes.isNotEmpty) return athletes.first.id;
    return 'unknown-athlete';
  }

  void _pushCadenceMetric() {
    final athleteId = _getAthleteIdFallback();
    try {
      context.read<MLService>().testMetrics['cadence'] = cadence;
    } catch (_) {}

    final id = '$athleteId-endurance-${DateTime.now().millisecondsSinceEpoch}';
    final assessment = Assessment(
      id: id,
      athleteId: athleteId,
      type: 'enduranceRun',
      timestamp: DateTime.now(),
      metrics: {'cadence': cadence},
    );
    try {
      SharedDataService().addAssessment(assessment);
      final athlete = SharedDataService().athleteById(athleteId);
      final sport = athlete?.metadata['sport']?.toString() ?? athleteId;
      MockAthleteProfiles.updateAssessment(sport, 'enduranceRun', cadence.toString(), unit: 'spm');
    } catch (_) {}
  }

  void onPose(PoseResult res) {
    frame++;
    final left = res.leftAnkle;
    final right = res.rightAnkle;
    bool leftVisible = left != null && left.score > 0.3;
    bool rightVisible = right != null && right.score > 0.3;

    if (leftVisible) stepCount++;
    if (rightVisible) stepCount++;

    // approximate cadence every 5 seconds
    if (frame % (fps * 5) == 0) {
      cadence = (stepCount / 5.0) * 60.0; // steps per minute
      stepCount = 0;

      // 💾 update cadence metric
      _pushCadenceMetric();

      setState(() {});
    }
  }

  @override
  void dispose() {
    try {
      context.read<MLService>().stopImageStream();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ml = Provider.of<MLService>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Endurance Run')),
      body: Column(
        children: [
          const Expanded(child: CameraPreviewWidget()),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text('Estimated cadence (spm): ${cadence.toStringAsFixed(1)}'),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          ml.resetTest('endurance'); // 🔄 reset metrics
                          await ml.loadModel();
                          await ml.startImageStream(onPose);
                        } catch (e) {
                          debugPrint('Error starting endurance: $e');
                        }
                      },
                      child: const Text('Start'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          await ml.stopImageStream();
                        } catch (_) {}
                      },
                      child: const Text('Stop'),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

/// Camera preview widget that uses MLService's controller
class CameraPreviewWidget extends StatelessWidget {
  const CameraPreviewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final ml = Provider.of<MLService>(context);
    if (ml.cameraController == null || !ml.cameraController!.value.isInitialized) {
      return const Center(
        child: Text('Camera not initialized', style: TextStyle(color: Colors.white70)),
      );
    }
    return CameraPreview(ml.cameraController!);
  }
}
