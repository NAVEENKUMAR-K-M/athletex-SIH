// lib/ml_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as imglib;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'utils.dart';

// New imports for syncing results
import 'services/shared_data_service.dart';
import 'models/athlete_profiles.dart';

class MLService extends ChangeNotifier {
  final CameraDescription? cameraDescription;
  CameraController? _cameraController;
  Interpreter? _interpreter;

  bool _modelLoaded = false;
  bool _streaming = false;

  int inputSize = 192;
  TensorType? inputType;
  List<int>? inputShape;

  PoseResult? latestResult;

  // used to share metrics between test screens and analysis screen
  String? currentTest;
  Map<String, dynamic> testMetrics = {
    'droppedFrames': 0,
    'processedFrames': 0,
    'avgProcessingMs': 0.0,
  };

  // track model path/name
  String? _currentModelPath;
  String? get currentModelName => _currentModelPath;

  // Streaming control & backpressure
  bool _processingFrame = false;
  int _streamFrameCounter = 0;

  // processing timing window
  final List<int> _processingTimesMs = [];

  // Recording flag
  bool _isRecording = false;

  MLService(this.cameraDescription);

  void resetTest(String name) {
    currentTest = name;
    testMetrics['droppedFrames'] = 0;
    testMetrics['processedFrames'] = 0;
    _processingTimesMs.clear();
    notifyListeners();
  }

  /// Initialize (or re-initialize) camera controller if cameraDescription is provided.
  /// Uses low preset to reduce memory pressure on devices and avoid ImageReader buffer exhaustion.
  Future<void> initCamera({ResolutionPreset preset = ResolutionPreset.low}) async {
    if (cameraDescription == null) return;
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      // already initialized
      return;
    }
    try {
      _cameraController = CameraController(
        cameraDescription!,
        preset,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _cameraController!.initialize();
      notifyListeners();
    } catch (e) {
      debugPrint('MLService.initCamera error: $e');
      rethrow;
    }
  }

  CameraController? get cameraController => _cameraController;
  bool get isRecording => _isRecording;

  /// Loads a tflite model from assets (default uses MoveNet singlepose lightning).
  Future<void> loadModel({String assetPath = 'assets/models/movenet_singlepose_lightning.tflite'}) async {
    if (_modelLoaded && _currentModelPath == assetPath) return;
    try {
      final options = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset(assetPath, options: options);

      final inputs = _interpreter!.getInputTensors();
      if (inputs.isNotEmpty) {
        final t = inputs.first;
        inputType = t.type;
        inputShape = t.shape;
        if (inputShape != null && inputShape!.length >= 4) {
          inputSize = inputShape![1];
        }
      }

      _modelLoaded = true;
      _currentModelPath = assetPath;
      notifyListeners();
    } catch (e) {
      debugPrint('MLService.loadModel error: $e');
      rethrow;
    }
  }

  // ---------------- Managed Recording API ----------------

  /// Initialize camera (lazily) and start recording. Returns true on success.
  Future<bool> startManagedRecording({ResolutionPreset preset = ResolutionPreset.medium}) async {
    // If already recording, ignore
    if (_isRecording) {
      debugPrint('startManagedRecording called but already recording');
      return true;
    }

    try {
      // init camera lazily if not present
      if (_cameraController == null || !(_cameraController!.value.isInitialized)) {
        await initCamera(preset: preset);
      }

      if (_cameraController == null) {
        debugPrint('startManagedRecording: no camera controller after init');
        return false;
      }

      // Prepare and start recording
      await _cameraController!.prepareForVideoRecording();
      await _cameraController!.startVideoRecording();
      _isRecording = true;
      notifyListeners();
      debugPrint('MLService: recording started');
      return true;
    } catch (e, st) {
      debugPrint('MLService.startManagedRecording error: $e\n$st');
      _isRecording = false;
      notifyListeners();
      return false;
    }
  }

  /// Stop recording and return the recorded file (XFile) or null on error.
  Future<XFile?> stopManagedRecording() async {
    if (!_isRecording) {
      debugPrint('stopManagedRecording: not recording');
      return null;
    }
    if (_cameraController == null) {
      debugPrint('stopManagedRecording: no controller');
      _isRecording = false;
      notifyListeners();
      return null;
    }

    try {
      final XFile file = await _cameraController!.stopVideoRecording();
      _isRecording = false;
      notifyListeners();
      debugPrint('MLService: recording stopped, path=${file.path}');
      return file;
    } catch (e, st) {
      debugPrint('MLService.stopManagedRecording error: $e\n$st');
      _isRecording = false;
      notifyListeners();
      return null;
    }
  }

  /// Dispose of the camera controller safely (stops streams if any) and free resources.
  Future<void> disposeCamera() async {
    try {
      // if streaming inference is running, stop it
      if (_streaming) {
        try {
          await stopImageStream();
        } catch (e) {
          debugPrint('disposeCamera: stopImageStream error: $e');
        }
      }

      // If recording, attempt to stop recording first (best-effort)
      if (_isRecording && _cameraController != null && _cameraController!.value.isRecordingVideo) {
        try {
          await _cameraController!.stopVideoRecording();
        } catch (e) {
          debugPrint('disposeCamera: stopVideoRecording error: $e');
        }
      }

      if (_cameraController != null) {
        try {
          await _cameraController!.dispose();
        } catch (e) {
          debugPrint('disposeCamera controller dispose error: $e');
        } finally {
          _cameraController = null;
        }
      }
    } catch (e) {
      debugPrint('disposeCamera unexpected: $e');
    } finally {
      _isRecording = false;
      _streaming = false;
      _processingFrame = false;
      notifyListeners();
    }
  }

  // ---------------- Live stream + inference ----------------

  /// Start streaming camera frames and run pose detection on them.
  ///
  /// Defaults to sampling 1 out of every 3 frames to reduce memory/cpu pressure.
  /// Uses a processing lock to drop frames while a frame is being processed.
  Future<void> startImageStream(void Function(PoseResult) onResult, {int processEveryNFrames = 3}) async {
    if (_streaming) {
      debugPrint('startImageStream called but already streaming');
      return; // already streaming
    }

    if (_cameraController == null) {
      try {
        await initCamera();
      } catch (e) {
        debugPrint('initCamera failed in startImageStream: $e');
        return;
      }
    }
    if (_cameraController == null) return;

    // ensure initialized
    if (!_cameraController!.value.isInitialized) {
      try {
        await _cameraController!.initialize();
      } catch (e) {
        debugPrint('camera initialize failed: $e');
        return;
      }
    }

    _streaming = true;
    _streamFrameCounter = 0;
    _processingFrame = false;
    testMetrics['droppedFrames'] = 0;
    testMetrics['processedFrames'] = 0;
    testMetrics['avgProcessingMs'] = 0.0;
    _processingTimesMs.clear();

    // Safety: clamp sampling to at least 1
    final int sample = (processEveryNFrames <= 1) ? 1 : processEveryNFrames;

    try {
      await _cameraController!.startImageStream((CameraImage image) async {
        // quick guard: if stream flagged stopped, return immediately
        if (!_streaming) return;

        // sample frames: skip frames to reduce load
        _streamFrameCounter++;
        if (_streamFrameCounter % sample != 0) {
          // count as dropped frame (sampling)
          testMetrics['droppedFrames'] = (testMetrics['droppedFrames'] as int) + 1;
          // notify occasionally so UI can show stats if needed
          if ((testMetrics['droppedFrames'] as int) % 50 == 0) notifyListeners();
          return;
        }

        // If another frame is being processed, drop this frame
        if (_processingFrame) {
          testMetrics['droppedFrames'] = (testMetrics['droppedFrames'] as int) + 1;
          if ((testMetrics['droppedFrames'] as int) % 50 == 0) notifyListeners();
          return;
        }

        // If interpreter/model not ready, skip heavy processing (but still keep preview)
        if (_interpreter == null || !_modelLoaded) {
          // mark dropped because model not ready
          testMetrics['droppedFrames'] = (testMetrics['droppedFrames'] as int) + 1;
          if ((testMetrics['droppedFrames'] as int) % 50 == 0) notifyListeners();
          return;
        }

        // Mark processing and run inference asynchronously
        _processingFrame = true;
        final stopwatch = Stopwatch()..start();
        try {
          final res = await runPoseOnFrame(image);
          stopwatch.stop();
          final ms = stopwatch.elapsedMilliseconds;
          _processingTimesMs.add(ms);
          // maintain a rolling average (last N)
          final lastN = 50;
          final takeCount = (_processingTimesMs.length < lastN) ? _processingTimesMs.length : lastN;
          final sum = _processingTimesMs.skip((_processingTimesMs.length - takeCount)).fold<int>(0, (a, b) => a + b);
          testMetrics['avgProcessingMs'] = (takeCount == 0) ? 0.0 : (sum / takeCount);
          // processed count
          testMetrics['processedFrames'] = (testMetrics['processedFrames'] as int) + 1;

          if (res != null) {
            latestResult = res;
            try {
              onResult(res);
            } catch (callbackError) {
              debugPrint('onResult callback error: $callbackError');
            }
          }
          // occasionally notify UI to update metrics display
          if ((testMetrics['processedFrames'] as int) % 10 == 0) notifyListeners();
        } catch (procError, st) {
          debugPrint('Error processing camera frame: $procError\n$st');
        } finally {
          // unlock quickly so next frame can be processed
          _processingFrame = false;
        }
      });
    } catch (e, st) {
      debugPrint('startImageStream exception: $e\n$st');
      _streaming = false;
      _processingFrame = false;
    }
  }

  /// Stop the image stream. Wait briefly for any in-flight processing to finish.
  Future<void> stopImageStream() async {
    if (!_streaming) return;
    _streaming = false;

    // Wait up to a short timeout for processing to finish
    final timeout = Duration(milliseconds: 500);
    final stopwatch = Stopwatch()..start();
    while (_processingFrame && stopwatch.elapsed < timeout) {
      await Future.delayed(const Duration(milliseconds: 20));
    }

    try {
      await _cameraController?.stopImageStream();
    } catch (e) {
      debugPrint('stopImageStream error: $e');
    } finally {
      _processingFrame = false;
    }
  }

  /// Convert CameraImage -> PoseResult by running the interpreter.
  Future<PoseResult?> runPoseOnFrame(CameraImage cameraImage) async {
    if (_interpreter == null) return null;
    try {
      final imglib.Image? rgb = convertCameraImage(cameraImage);
      if (rgb == null) return null;

      final imglib.Image resized = imglib.copyResizeCropSquare(rgb, size: inputSize);

      dynamic inputTensor;
      if (inputType == TensorType.uint8) {
        inputTensor = imageToByteListUint8(resized);
      } else {
        inputTensor = imageToFloat32ListNormalized(resized);
      }

      // Prepare output buffer according to common movenet shape: [1,17,3]
      final output = List.generate(1, (_) => List.generate(17, (_) => List.filled(3, 0.0)));

      try {
        _interpreter!.run(inputTensor, output);
      } catch (e) {
        // some interpreters expect the input wrapped in a list
        try {
          _interpreter!.run([inputTensor], output);
        } catch (inner) {
          debugPrint('Interpreter run failed: $e, $inner');
          return null;
        }
      }

      final w = resized.width, h = resized.height;
      final keypoints = <KeyPoint>[];
      for (int i = 0; i < 17; i++) {
        final dy = output[0][i][0];
        final dx = output[0][i][1];
        final sc = output[0][i][2];
        final y = (dy is num) ? dy.toDouble() : double.tryParse(dy.toString()) ?? 0.0;
        final x = (dx is num) ? dx.toDouble() : double.tryParse(dx.toString()) ?? 0.0;
        final s = (sc is num) ? sc.toDouble() : double.tryParse(sc.toString()) ?? 0.0;
        keypoints.add(KeyPoint(name: '$i', x: x * w, y: y * h, score: s));
      }

      return PoseResult(keypoints: keypoints, imageWidth: w, imageHeight: h);
    } catch (e) {
      debugPrint('runPoseOnFrame unexpected error: $e');
      return null;
    }
  }

  /// Analyze a recorded video file (path). This is a simple, safe stub that:
  /// - records that the video was analyzed in testMetrics
  /// - pushes a single 'video_analysis' Assessment into SharedDataService
  /// - mirrors the result into MockAthleteProfiles for backward compatibility
  ///
  /// Replace this with real video processing logic (frame extraction + runPoseOnFrame)
  Future<void> analyzeRecordedVideo(String path) async {
    if (path.isEmpty) return;
    // mark metric
    testMetrics['videoAnalyzed'] = true;
    testMetrics['videoPath'] = path;
    notifyListeners();

    // create a basic assessment record so UI can pick it up
    final athleteId = _getAthleteIdFallback();
    final id = '$athleteId-video-${DateTime.now().millisecondsSinceEpoch}';
    final assessment = Assessment(
      id: id,
      athleteId: athleteId,
      type: 'video_analysis',
      timestamp: DateTime.now(),
      metrics: {
        'path': path,
        'note': 'analyzed (stub)',
      },
    );

    try {
      SharedDataService().addAssessment(assessment);

      // Mirror into MockAthleteProfiles if possible (uses sport key)
      final athlete = SharedDataService().athleteById(athleteId);
      final sport = athlete?.metadata['sport']?.toString() ?? athleteId;
      MockAthleteProfiles.updateAssessment(sport, 'videoAnalysis', 'done');
    } catch (e) {
      debugPrint('analyzeRecordedVideo push error: $e');
    }
  }

  String _getAthleteIdFallback() {
    try {
      final shared = SharedDataService();
      final athletes = shared.athletes;
      if (athletes.isNotEmpty) return athletes.first.id;
    } catch (_) {}
    return 'unknown-athlete';
  }

  @override
  void dispose() {
    try {
      _cameraController?.dispose();
    } catch (_) {}
    try {
      _interpreter?.close();
    } catch (_) {}
    super.dispose();
  }

  // ---------- Helper converters (kept from your utils) ----------
  // Using runtime checks to support both `int` pixel and `imglib.Pixel` pixel types.

  Uint8List imageToByteListUint8(imglib.Image image) {
    final convertedBytes = Uint8List(inputSize * inputSize * 3);
    int index = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final dynamic p = image.getPixel(x, y);
        int r = 0, g = 0, b = 0;
        if (p is int) {
          r = (p >> 16) & 0xFF;
          g = (p >> 8) & 0xFF;
          b = p & 0xFF;
        } else if (p is imglib.Pixel) {
          r = (p.r as num).toInt();
          g = (p.g as num).toInt();
          b = (p.b as num).toInt();
        } else {
          final intVal = int.tryParse(p.toString()) ?? 0;
          r = (intVal >> 16) & 0xFF;
          g = (intVal >> 8) & 0xFF;
          b = intVal & 0xFF;
        }
        convertedBytes[index++] = r;
        convertedBytes[index++] = g;
        convertedBytes[index++] = b;
      }
    }
    return convertedBytes;
  }

  List<List<List<double>>> imageToFloat32ListNormalized(imglib.Image image) {
    final input = List.generate(
      inputSize,
      (_) => List.generate(inputSize, (_) => List.filled(3, 0.0)),
    );
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final dynamic p = image.getPixel(x, y);
        double r = 0, g = 0, b = 0;
        if (p is int) {
          r = ((p >> 16) & 0xFF).toDouble();
          g = ((p >> 8) & 0xFF).toDouble();
          b = (p & 0xFF).toDouble();
        } else if (p is imglib.Pixel) {
          r = (p.r as num).toDouble();
          g = (p.g as num).toDouble();
          b = (p.b as num).toDouble();
        } else {
          final intVal = int.tryParse(p.toString()) ?? 0;
          r = ((intVal >> 16) & 0xFF).toDouble();
          g = ((intVal >> 8) & 0xFF).toDouble();
          b = (intVal & 0xFF).toDouble();
        }
        input[y][x][0] = (r - 127.5) / 127.5;
        input[y][x][1] = (g - 127.5) / 127.5;
        input[y][x][2] = (b - 127.5) / 127.5;
      }
    }
    return input;
  }
}
