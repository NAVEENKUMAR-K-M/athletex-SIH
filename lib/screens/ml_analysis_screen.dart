// lib/screens/ml_analysis_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;

import '../widgets/card.dart' as ui;
import '../../widgets/custom_button.dart';
import '../../services/gemini_api.dart';
import '../widgets/progress_bar.dart';
import '../ml_service.dart';
import '../../services/shared_data_service.dart';
import '../../models/athlete_profiles.dart';

/// Worker entrypoint for isolate analysis.
/// Communicates using simple Maps and SendPorts (isolate-safe).
void _frameAnalysisWorker(SendPort initialReplyPort) async {
  final port = ReceivePort();
  initialReplyPort.send(port.sendPort);

  await for (final dynamic incoming in port) {
    try {
      if (incoming is List && incoming.length >= 2) {
        final req = incoming[0] as Map;
        final SendPort replyPort = incoming[1] as SendPort;
        final String imagePath = req['imagePath'] as String;

        final bytes = await File(imagePath).readAsBytes();
        final decoded = img.decodeImage(bytes);

        double brightness = 0.0;
        if (decoded != null) {
          final raw = decoded.getBytes(); // RGBA byte array
          int sum = 0;
          int count = 0;
          for (int i = 0; i + 2 < raw.length; i += 4) {
            final r = raw[i];
            final g = raw[i + 1];
            final b = raw[i + 2];
            sum += ((r + g + b) ~/ 3);
            count++;
          }
          brightness = count > 0 ? (sum / count) : 0.0;
        }

        // Mock inference: brightness -> speed & angle
        final double speed = (brightness / 255.0) * 5.0;
        final double angle = (brightness / 255.0) * 90.0;

        final reply = {
          'framePath': imagePath,
          'result': {
            'speed_m_s': double.parse(speed.toStringAsFixed(3)),
            'angle_deg': double.parse(angle.toStringAsFixed(2)),
            'confidence': 0.8
          }
        };

        replyPort.send(reply);
      } else {
        // ignore unknown messages
      }
    } catch (e) {
      try {
        if (incoming is List && incoming.length >= 2) {
          final SendPort replyPort = incoming[1] as SendPort;
          replyPort.send({'error': e.toString()});
        }
      } catch (_) {}
    }
  }
}

class MLAnalysisScreen extends StatefulWidget {
  final VoidCallback onBack;
  const MLAnalysisScreen({super.key, required this.onBack});

  @override
  State<MLAnalysisScreen> createState() => _MLAnalysisScreenState();
}

class _MLAnalysisScreenState extends State<MLAnalysisScreen> {
  double progress = 0.0;
  Map<String, dynamic>? analysisResult;
  String? insights;
  bool loadingInsights = false;
  bool _pipelineRunning = false;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  // ---------- Utilities ----------
  Map<String, dynamic> _reportDefaults() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'video_duration_s': 0.0,
      'frame_count': 0,
      'avg_speed_m_s': null,
      'max_speed_m_s': null,
      'avg_angle_deg': null,
      'max_angle_deg': null,
      'analyzed': false,
      'defaults': {
        'avg_speed_m_s': 0.0,
        'max_speed_m_s': 0.0,
        'avg_angle_deg': 0.0,
        'max_angle_deg': 0.0,
      }
    };
  }

  String _formatStat(dynamic v) {
    if (v == null) return '-';
    return v.toString();
  }

  String _getAthleteIdFallback() {
    try {
      final shared = SharedDataService();
      final athletes = shared.athletes;
      if (athletes.isNotEmpty) return athletes.first.id;
    } catch (_) {}
    return 'unknown-athlete';
  }

  // ---------- Frame extraction ----------
  Future<List<String>> _extractFrames(String videoPath, {int fps = 1}) async {
    final tmpDir = await getTemporaryDirectory();
    final framesDir = Directory('${tmpDir.path}/frames_${Uuid().v4()}');
    await framesDir.create();

    final outPattern = '${framesDir.path}/frame_%04d.png';
    final cmd = '-i "$videoPath" -vf fps=$fps "$outPattern"';
    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (returnCode != null && returnCode.isValueSuccess()) {
      final files = framesDir
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .toList()
        ..sort();
      return files;
    } else {
      throw Exception('FFmpeg failed (rc=$returnCode)');
    }
  }

  // ---------- Analyze single frame in an isolate ----------
  Future<Map<String, dynamic>> _analyzeFrameInIsolate(String framePath, {String? modelPath}) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(_frameAnalysisWorker, receivePort.sendPort);

    final completer = Completer<Map<String, dynamic>>();
    final replyPort = ReceivePort();

    StreamSubscription? handshakeSub;
    handshakeSub = receivePort.listen((message) {
      if (message is SendPort) {
        final req = {'imagePath': framePath, 'modelPath': modelPath};
        message.send([req, replyPort.sendPort]);
        handshakeSub?.cancel();
      }
    });

    replyPort.listen((msg) {
      if (msg is Map) {
        if (msg.containsKey('error')) {
          completer.completeError(Exception(msg['error']));
        } else {
          completer.complete(msg as Map<String, dynamic>);
        }
      } else {
        completer.completeError(Exception('Invalid worker reply'));
      }
      try {
        replyPort.close();
        receivePort.close();
        isolate.kill(priority: Isolate.immediate);
      } catch (_) {}
    });

    return completer.future;
  }

  // ---------- Aggregation ----------
  Map<String, dynamic> _aggregateResults(List<Map<String, dynamic>> frameResults, Map<String, dynamic> baseReport) {
    final speeds = <double>[];
    final angles = <double>[];

    for (var fr in frameResults) {
      final r = fr['result'] as Map<String, dynamic>?;
      if (r == null) continue;
      if (r['speed_m_s'] is num) speeds.add((r['speed_m_s'] as num).toDouble());
      if (r['angle_deg'] is num) angles.add((r['angle_deg'] as num).toDouble());
    }

    if (speeds.isNotEmpty) {
      final avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
      final maxSpeed = speeds.reduce((a, b) => a > b ? a : b);
      baseReport['avg_speed_m_s'] = double.parse(avgSpeed.toStringAsFixed(3));
      baseReport['max_speed_m_s'] = double.parse(maxSpeed.toStringAsFixed(3));
    }

    if (angles.isNotEmpty) {
      final avgAngle = angles.reduce((a, b) => a + b) / angles.length;
      final maxAngle = angles.reduce((a, b) => a > b ? a : b);
      baseReport['avg_angle_deg'] = double.parse(avgAngle.toStringAsFixed(2));
      baseReport['max_angle_deg'] = double.parse(maxAngle.toStringAsFixed(2));
    }

    baseReport['frame_count'] = frameResults.length;
    baseReport['analyzed'] = frameResults.isNotEmpty;
    return baseReport;
  }

  // ---------- Full pipeline ----------
  Future<Map<String, dynamic>> _analyzeVideoFilePipeline(String videoPath,
      {int fps = 1, String? modelPath, void Function(double)? onProgress}) async {
    final report = _reportDefaults();
    List<String> frames = [];
    try {
      onProgress?.call(5);
      frames = await _extractFrames(videoPath, fps: fps);
      onProgress?.call(15);
    } catch (e) {
      report['error'] = 'frame_extraction_failed';
      report['error_msg'] = e.toString();
      return report;
    }

    final results = <Map<String, dynamic>>[];
    const int batchSize = 3;
    for (int i = 0; i < frames.length; i += batchSize) {
      final batch = frames.skip(i).take(batchSize).toList();
      final futures = batch.map((fp) => _analyzeFrameInIsolate(fp, modelPath: modelPath)).toList();
      try {
        final batchRes = await Future.wait(futures);
        results.addAll(batchRes);
      } catch (e) {
        debugPrint('Frame analysis error: $e');
      }
      final percent = 15 + ((i / (frames.isEmpty ? 1 : frames.length)) * 70);
      onProgress?.call(percent.clamp(15.0, 85.0));
    }

    onProgress?.call(90.0);
    final aggregated = _aggregateResults(results, report);

    // cleanup frames
    try {
      if (frames.isNotEmpty) {
        final parent = Directory(frames.first).parent;
        if (await parent.exists()) {
          await parent.delete(recursive: true);
        }
      }
    } catch (_) {}

    final defaults = aggregated['defaults'] as Map<String, dynamic>;
    final output = <String, dynamic>{
      'timestamp': aggregated['timestamp'],
      'video_duration_s': aggregated['video_duration_s'],
      'frame_count': aggregated['frame_count'],
      'analyzed': aggregated['analyzed'],
    };

    for (var k in defaults.keys) {
      output[k] = aggregated.containsKey(k) && aggregated[k] != null ? aggregated[k] : defaults[k];
    }

    onProgress?.call(100.0);
    return output;
  }

  // ---------- Main UI-triggered pipeline ----------
  Future<void> _startAnalysis() async {
    if (_pipelineRunning) return;
    setState(() {
      progress = 0.0;
      analysisResult = null;
      insights = null;
      _pipelineRunning = true;
    });

    final ml = context.read<MLService>();

    try {
      String? recordedPath;
      try {
        final dyn = ml as dynamic;
        recordedPath = dyn.lastRecordedVideoPath ?? dyn.recordedVideoPath ?? dyn.recentRecordedPath;
      } catch (_) {
        recordedPath = null;
      }

      if (recordedPath != null && recordedPath.isNotEmpty && File(recordedPath).existsSync()) {
        final resultMap = await _analyzeVideoFilePipeline(recordedPath, fps: 1, onProgress: (p) {
          if (mounted) setState(() => progress = p);
        });

        int? formScore;
        double xpGained = 0.0;
        final avgSpeed = (resultMap['avg_speed_m_s'] as num?)?.toDouble();
        if (avgSpeed != null) {
          formScore = (avgSpeed / 5.0 * 100).round().clamp(0, 100);
          xpGained = (formScore / 2).roundToDouble();
        }

        final cheatDetection = {
          'flagged': (formScore != null) ? (formScore < 60) : false,
          'events': (formScore != null && formScore < 60)
              ? [
                  {'type': 'Low score from video pipeline', 'note': 'Check camera framing.'}
                ]
              : []
        };

        final finalResult = {
          'pipeline': resultMap,
          'formScore': formScore,
          'xpGained': xpGained.toInt(),
          'cheatDetection': cheatDetection,
          'timestamp': DateTime.now().toIso8601String(),
        };

        if (!mounted) return;
        setState(() {
          analysisResult = finalResult;
          progress = 100.0;
          _pipelineRunning = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Video pipeline failed: $e');
    }

    // Fallback to MLService.testMetrics
    final m = ml.testMetrics;
    final int? reps = (m['reps'] is num) ? (m['reps'] as num).toInt() : null;
    final double? jump = (m['jumpHeight'] is num) ? (m['jumpHeight'] as num).toDouble() : null;
    final int? laps = (m['laps'] is num) ? (m['laps'] as num).toInt() : null;
    final double? cadence = (m['cadence'] is num) ? (m['cadence'] as num).toDouble() : null;
    final hasAnyMetric = reps != null || jump != null || laps != null || cadence != null;

    int? formScore;
    double xpGained = 0.0;
    Map<String, dynamic> cheatDetection = {'flagged': false, 'events': []};

    if (hasAnyMetric) {
      final double scoreReps = (reps != null) ? (reps * 2.0).clamp(0.0, 40.0) : 0.0;
      final double scoreJump = (jump != null) ? (jump * 10.0).clamp(0.0, 30.0) : 0.0;
      final double scoreLaps = (laps != null) ? (laps * 3.0).clamp(0.0, 20.0) : 0.0;
      final double scoreCadence = (cadence != null) ? (cadence / 2.0).clamp(0.0, 10.0) : 0.0;

      final double formScoreDouble = (scoreReps + scoreJump + scoreLaps + scoreCadence).clamp(0.0, 100.0);
      formScore = formScoreDouble.round();
      xpGained = (formScore / 2).roundToDouble();

      cheatDetection = {
        'flagged': formScore < 60,
        'events': formScore < 60
            ? [
                {
                  'type': 'Form issues',
                  'reps': reps ?? '-',
                  'severity': 'Low',
                  'note': 'Review posture and range of motion'
                }
              ]
            : []
      };
    }

    final result = {
      'reps': reps,
      'jumpHeight': jump,
      'laps': laps,
      'cadence': cadence,
      'formScore': formScore,
      'xpGained': xpGained.toInt(),
      'cheatDetection': cheatDetection,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (!mounted) return;
    setState(() {
      analysisResult = result;
      progress = 100.0;
      _pipelineRunning = false;
    });
  }

  // ---------- Insights ----------
  Future<void> _getInsights() async {
    if (analysisResult == null) return;
    setState(() => loadingInsights = true);
    final prompt =
        "Performance analysis: form score ${analysisResult!['formScore'] ?? 'N/A'}, issues: ${(analysisResult!['cheatDetection']['events'] as List).map((e) => e['type']).join(', ')}. Provide concise coaching tips.";
    try {
      final response = await GeminiApi.callGeminiApi(prompt);
      if (!mounted) return;
      setState(() {
        insights = response['insights'] ?? response['text'] ?? "No tips received.";
        loadingInsights = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        insights = "AI tips unavailable: $e";
        loadingInsights = false;
      });
    }
  }

  Future<void> _submitAnalysis() async {
    if (analysisResult == null) return;
    final shared = context.read<SharedDataService>();
    final athleteId = _getAthleteIdFallback();

    final metrics = Map<String, dynamic>.from(analysisResult!);
    if (insights != null && insights!.isNotEmpty) {
      metrics['insights'] = insights;
    }

    final id = '$athleteId-analysis-${DateTime.now().millisecondsSinceEpoch}';
    final assessment = Assessment(
      id: id,
      athleteId: athleteId,
      type: 'ml_analysis',
      timestamp: DateTime.now(),
      metrics: metrics,
    );

    try {
      shared.addAssessment(assessment);
    } catch (e) {
      debugPrint('Failed to add assessment: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analysis saved to athlete profile')),
    );

    widget.onBack();
  }

  // ---------- UI helpers ----------
  Widget _smallStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, color: Colors.white)),
      ],
    );
  }

  Widget _buildCheatReport() {
    final events = (analysisResult!['cheatDetection']?['events'] ?? []) as List;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Possible issues detected', style: TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 8),
          for (var e in events) Text("• ${e['type'] ?? 'Issue'} — ${e['note'] ?? ''}", style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildInsightsBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(insights ?? '', style: const TextStyle(color: Colors.white70)),
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
                const SizedBox(height: 12),
                const Text("ML Analysis", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 24),

                if (_pipelineRunning) ...[
                  const Text("Analyzing video frames...", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  ProgressBar(value: progress, max: 100),
                  const SizedBox(height: 8),
                  Text("${progress.toStringAsFixed(0)}%", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                ] else if (analysisResult == null) ...[
                  const Text("Analyzing performance.", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ProgressBar(value: progress, max: 100),
                ] else ...[
                  // Results card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text("Overall Form Score", style: TextStyle(color: Colors.grey, fontSize: 14)),
                        const SizedBox(height: 8),
                        if (analysisResult!['formScore'] == null)
                          Column(
                            children: const [
                              Text("No reliable score", style: TextStyle(fontSize: 18, color: Colors.grey)),
                              SizedBox(height: 8),
                              Text("Make sure the recording captured the exercise fully.", style: TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          )
                        else
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(text: "${analysisResult!['formScore']}", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.yellow)),
                              const TextSpan(text: "/100", style: TextStyle(fontSize: 20, color: Colors.grey)),
                            ]),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _smallStat("Reps", _formatStat(analysisResult!['reps'])),
                            _smallStat("Jump (m)", _formatStat(analysisResult!['jumpHeight'])),
                            _smallStat("Laps", _formatStat(analysisResult!['laps'])),
                            _smallStat("Cadence", _formatStat(analysisResult!['cadence'])),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  if ((analysisResult!['cheatDetection']?['flagged'] ?? false) == true) ...[
                    _buildCheatReport(),
                    const SizedBox(height: 12),
                  ],

                  if (insights == null && !loadingInsights)
                    CustomButton(
                      text: "Get AI Performance Tips",
                      onPressed: _getInsights,
                      icon: Icons.auto_awesome,
                      backgroundColor: Colors.purple.shade600,
                    )
                  else if (loadingInsights)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text("✨ Generating insights.", style: TextStyle(color: Colors.grey, fontSize: 14)),
                    )
                  else if (insights != null) ...[
                    const SizedBox(height: 12),
                    _buildInsightsBox(),
                  ],

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: "Submit",
                          onPressed: _submitAnalysis,
                          icon: Icons.check_circle,
                          backgroundColor: Colors.green.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CustomButton(
                          text: "Back",
                          onPressed: widget.onBack,
                          icon: Icons.arrow_back,
                          backgroundColor: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
