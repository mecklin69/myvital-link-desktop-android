import 'dart:math' as math;
import 'package:flutter/material.dart';

class HighEndECGPainter extends CustomPainter {
  final double sweepProgress;
  final Color color;
  final bool isDarkMode;
  final List<double> beatHeights;

  // For your visual test: set this to true for the V1 instance
  final bool isNegativeLead;

  HighEndECGPainter({
    required this.sweepProgress,
    required this.color,
    this.isDarkMode = false,
    required this.beatHeights,
    this.isNegativeLead = false
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double safeHeight = size.height * 0.85;
    final double midY = size.height / 2;
    final double scanX = size.width * sweepProgress;
    final bool isRes = color == Colors.blue;
    final double vScale = safeHeight / size.height;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = isRes ? 1.8 : 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (isDarkMode) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.12)
        ..strokeWidth = isRes ? 4.0 : 3.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      _drawWavePath(canvas, size, glowPaint, scanX, midY, isRes, vScale);
    }

    _drawWavePath(canvas, size, linePaint, scanX, midY, isRes, vScale);

    final double headY = isRes
        ? _getRespirationY(scanX, midY, size.height, vScale)
        : _getBiologicalECGY(scanX, midY, size.height, vScale);

    // Scan Head
    canvas.drawCircle(Offset(scanX, headY), 2.5, Paint()..color = Colors.white);
  }

  void _drawWavePath(Canvas canvas, Size size, Paint paint, double scanX, double midY, bool isRes, double vScale) {
    final Path path = Path();
    const double eraseGap = 25.0;
    bool isFirstPoint = true;

    for (double x = 0; x < size.width; x += 1.5) {
      double dist = x - scanX;
      bool inGap = (dist < 0 && dist > -eraseGap) || (scanX < eraseGap && x > (size.width - (eraseGap - scanX)));

      if (inGap) {
        isFirstPoint = true;
        continue;
      }

      double y = isRes
          ? _getRespirationY(x, midY, size.height, vScale)
          : _getBiologicalECGY(x, midY, size.height, vScale);

      if (isFirstPoint) {
        path.moveTo(x, y);
        isFirstPoint = false;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  double _getBiologicalECGY(double x, double midY, double h, double scale) {
    int beatIndex = (x / 140).floor();
    double amp = (beatIndex < beatHeights.length) ? beatHeights[beatIndex] : 1.0;
    double localX = x % 140;
    double wave = 0;

    // --- ECG Components ---
    if (localX > 30 && localX < 42) {
      // QRS Complex (The Main Spike)
      // We apply the 'isNegativeLead' flip here
      double qrsHeight = (h * 0.45 * amp) * scale;
      wave = isNegativeLead
          ? -math.sin((localX - 30) * (math.pi / 12)) * qrsHeight // Downward spike
          : math.sin((localX - 30) * (math.pi / 12)) * qrsHeight;  // Upward spike

    } else if (localX > 65 && localX < 95) {
      // T-Wave (Usually follows the direction of the QRS in some leads,
      // but we'll keep it slight for the visual test)
      double tWaveHeight = (h * 0.08 * amp) * scale;
      wave = isNegativeLead ? -math.sin((localX - 65) * (math.pi / 30)) * tWaveHeight : math.sin((localX - 65) * (math.pi / 30)) * tWaveHeight;

    } else if (localX > 5 && localX < 18) {
      // P-Wave
      wave = math.sin((localX - 5) * (math.pi / 13)) * (h * 0.04) * scale;
    }

    double noise = (math.Random(x.toInt()).nextDouble() - 0.5) * 1.2;
    return midY - (wave + noise);
  }

  double _getRespirationY(double x, double midY, double h, double scale) {
    double amp = (h * 0.22) * scale;
    double localX = x % 300;
    double wave = 0;
    if (localX < 40) wave = (localX / 40) * amp;
    else if (localX < 140) wave = amp + ((localX - 40) * 0.03 * scale);
    else if (localX < 175) wave = (amp + (100 * 0.03)) * (1 - (localX - 140) / 35);
    return midY - (wave + (math.Random(x.toInt()).nextDouble() - 0.5) * 1.0);
  }

  @override
  bool shouldRepaint(HighEndECGPainter old) => true;
}