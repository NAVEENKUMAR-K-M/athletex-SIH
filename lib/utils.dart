// lib/utils.dart
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as imglib;

// Import shared service to provide safe fallback helpers.
// Adjust path if your project places the service elsewhere.
import 'services/shared_data_service.dart';

/// ----- Models -----
class KeyPoint {
  final String name;
  final double x;
  final double y;
  final double score;
  const KeyPoint({
    required this.name,
    required this.x,
    required this.y,
    required this.score,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'x': x,
        'y': y,
        'score': score,
      };
}

class PoseResult {
  final List<KeyPoint> keypoints;
  final int imageWidth;
  final int imageHeight;
  const PoseResult({
    required this.keypoints,
    required this.imageWidth,
    required this.imageHeight,
  });

  KeyPoint? getKeypoint(int index) =>
      (index < 0 || index >= keypoints.length) ? null : keypoints[index];

  KeyPoint? get leftHip => getKeypoint(11);
  KeyPoint? get rightHip => getKeypoint(12);
  KeyPoint? get leftShoulder => getKeypoint(5);
  KeyPoint? get rightShoulder => getKeypoint(6);
  KeyPoint? get leftAnkle => getKeypoint(15);
  KeyPoint? get rightAnkle => getKeypoint(16);

  /// Trunk angle (deg) between shoulder and hip line (rough)
  double trunkAngle() {
    final s = leftShoulder ?? rightShoulder;
    final h = leftHip ?? rightHip;
    if (s == null || h == null) return 0.0;
    return _angleBetween(s.x, s.y, h.x, h.y).abs();
  }

  double _angleBetween(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return atan2(dy, dx) * 180 / pi;
  }

  Map<String, dynamic> toMap() => {
        'imageWidth': imageWidth,
        'imageHeight': imageHeight,
        'keypoints': keypoints.map((k) => k.toMap()).toList(),
      };
}

/// ----- Shared-service helpers -----
/// Safe fallback to get an athlete id from SharedDataService singleton.
/// Returns 'unknown-athlete' if none found or on any error.
String getAthleteIdFallback() {
  try {
    final shared = SharedDataService();
    final athletes = shared.athletes;
    if (athletes.isNotEmpty) return athletes.first.id;
  } catch (_) {
    // ignore and fall through
  }
  return 'unknown-athlete';
}

/// Convert a PoseResult to a plain Map so callers can persist it into SharedDataService
/// without depending on the internal types here.
Map<String, dynamic> poseResultToMap(PoseResult res) => res.toMap();

/// ----- Image helpers (package:image v4 APIs) -----
///
/// These helpers are used by MLService; they are defensive about pixel types
/// and cast to the correct numeric types for model inputs.

// Convert YUV420 CameraImage to RGB (imglib.Image).
imglib.Image? convertCameraImage(CameraImage image) {
  try {
    final w = image.width, h = image.height;
    final imglib.Image img = imglib.Image(width: w, height: h);

    if (image.planes.length < 3) {
      debugPrint('convertCameraImage: expected 3 planes (got ${image.planes.length})');
      return null;
    }

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int row = 0; row < h; row++) {
      final yRowBase = row * yRowStride;
      final uvRowBase = (row >> 1) * uvRowStride;
      for (int col = 0; col < w; col++) {
        final yIndex = yRowBase + col;
        final uvIndex = uvRowBase + (col >> 1) * uvPixelStride;
        if (yIndex >= yBytes.length || uvIndex >= uBytes.length || uvIndex >= vBytes.length) continue;

        final Y = yBytes[yIndex] & 0xFF;
        final U = uBytes[uvIndex] & 0xFF;
        final V = vBytes[uvIndex] & 0xFF;

        final yf = Y.toDouble();
        final uf = (U - 128).toDouble();
        final vf = (V - 128).toDouble();

        int r = (yf + 1.402 * vf).round();
        int g = (yf - 0.344136 * uf - 0.714136 * vf).round();
        int b = (yf + 1.772 * uf).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        img.setPixelRgb(col, row, r, g, b);
      }
    }
    return img;
  } catch (e, st) {
    debugPrint('convertCameraImage error: $e\n$st');
    return null;
  }
}

/// NHWC uint8 buffer (0..255)
Uint8List imageToByteListUint8(imglib.Image image) {
  final w = image.width, h = image.height;
  final out = Uint8List(w * h * 3);
  int i = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      // pixel channels in package:image v4 are num, so cast safely
      final int r = (p.r as num).toInt();
      final int g = (p.g as num).toInt();
      final int b = (p.b as num).toInt();
      out[i++] = r;
      out[i++] = g;
      out[i++] = b;
    }
  }
  return out;
}

/// NHWC float32 buffer normalized to [-1, 1]
Float32List imageToFloat32ListNormalized(imglib.Image image) {
  final w = image.width, h = image.height;
  final out = Float32List(w * h * 3);
  int i = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      final double r = (p.r as num).toDouble();
      final double g = (p.g as num).toDouble();
      final double b = (p.b as num).toDouble();
      out[i++] = (r - 127.5) / 127.5;
      out[i++] = (g - 127.5) / 127.5;
      out[i++] = (b - 127.5) / 127.5;
    }
  }
  return out;
}
