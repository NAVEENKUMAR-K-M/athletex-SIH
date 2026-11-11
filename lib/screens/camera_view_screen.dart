// lib/screens/camera_view_screen.dart
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/card.dart' as ui;
import '../../widgets/custom_button.dart';
import '../ml_service.dart';

class CameraViewScreen extends StatefulWidget {
  final String testName;
  final VoidCallback onStartAnalysis; // called after analysis is queued/completed
  final VoidCallback onBack;

  const CameraViewScreen({
    super.key,
    required this.testName,
    required this.onStartAnalysis,
    required this.onBack,
  });

  @override
  State<CameraViewScreen> createState() => _CameraViewScreenState();
}

class _CameraViewScreenState extends State<CameraViewScreen> {
  CameraController? _controller;
  bool _initializing = false;
  bool _recording = false;
  bool _analyzing = false;

  Future<void> _initCameraLocally() async {
    if (_controller != null && _controller!.value.isInitialized) return;
    setState(() => _initializing = true);
    try {
      final cameras = await availableCameras();
      final cam = cameras.isNotEmpty ? cameras.first : null;
      if (cam == null) {
        throw Exception('No available camera on device.');
      }
      _controller = CameraController(cam, ResolutionPreset.medium, enableAudio: true);
      await _controller!.initialize();
      if (mounted) setState(() => _initializing = false);
    } catch (e) {
      if (mounted) setState(() => _initializing = false);
      debugPrint('Camera init error: $e');
      rethrow;
    }
  }

  Future<void> _disposeCameraLocally() async {
    try {
      if (_controller != null) {
        if (_controller!.value.isRecordingVideo) {
          try {
            await _controller!.stopVideoRecording();
          } catch (_) {}
        }
        await _controller!.dispose();
      }
    } catch (e) {
      debugPrint('Error disposing camera: $e');
    } finally {
      _controller = null;
    }
  }

  Future<void> _startRecording() async {
    if (_recording) return;
    try {
      await _initCameraLocally();
      if (_controller == null || !_controller!.value.isInitialized) return;

      await _controller!.prepareForVideoRecording();
      await _controller!.startVideoRecording();
      setState(() {
        _recording = true;
      });
    } catch (e) {
      debugPrint('Start recording error: $e');
      await _disposeCameraLocally();
      if (mounted) setState(() {
        _recording = false;
        _initializing = false;
      });
    }
  }

  Future<void> _stopRecordingAndAnalyze() async {
    if (!_recording || _controller == null) return;
    XFile? file;
    try {
      file = await _controller!.stopVideoRecording();
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }

    setState(() {
      _recording = false;
      _analyzing = true;
    });

    // Dispose camera immediately to free buffers/resources
    await _disposeCameraLocally();

    // Use MLService to analyze recorded file (MLService.analyzeRecordedVideo exists in your MLService)
    try {
      final ml = context.read<MLService>();

      // Ensure model is loaded if your analysis needs it.
      // We call the public API loadModel() (don't access private fields).
      try {
        await ml.loadModel();
      } catch (e) {
        // loading may fail or be unnecessary for stub analysis; continue gracefully
        debugPrint('loadModel() failed or not required: $e');
      }

      if (file != null) {
        await ml.analyzeRecordedVideo(file.path);
      }

      // Notify parent that analysis is complete or queued (parent will navigate to results)
      if (mounted) {
        widget.onStartAnalysis();
      }
    } catch (e) {
      debugPrint('Error analyzing recorded video: $e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  void dispose() {
    _disposeCameraLocally();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final instructions = {
      'Vertical Jump': 'Stand side-on to the camera. Ensure your full body is visible. Jump as high as you can.',
      'Shuttle Run': 'Place the camera facing the shuttle run path. Make sure both ends are in view.',
      'Sit-ups': 'Position the camera from the side. Ensure your upper body and knees are visible.',
      'Endurance Run': 'This test may require GPS tracking; keep your phone on you during the run.'
    };

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
                  "Prepare for ${widget.testName}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.black,
                      child: _buildPreviewArea(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  instructions[widget.testName] ?? '',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Record + Analysis button
                if (_analyzing) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Analyzing video...', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: "Back",
                    onPressed: widget.onBack,
                    backgroundColor: Colors.grey.shade600,
                  ),
                ] else ...[
                  CustomButton(
                    text: _recording ? "Stop Recording" : "Start Recording",
                    onPressed: _recording ? _stopRecordingAndAnalyze : _startRecording,
                    backgroundColor: _recording ? Colors.red.shade600 : Colors.green.shade600,
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: "Back",
                    onPressed: () async {
                      // If user pressed Back while recording, stop & analyze first.
                      if (_recording) {
                        await _stopRecordingAndAnalyze();
                      }
                      widget.onBack();
                    },
                    backgroundColor: Colors.grey.shade600,
                  ),
                ],
                const SizedBox(height: 8),
                if (!_recording && !_analyzing)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Camera active only while recording.",
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyan));
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: Text('Camera inactive', style: TextStyle(color: Colors.white70)),
      );
    }
    return CameraPreview(_controller!);
  }
}
