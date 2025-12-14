// ABOUTME: Circular progress indicator showing recording progress toward 6 seconds.
// ABOUTME: Displays segmented progress for each clip with animation during recording.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/recorded_clip.dart';

/// Circular progress ring showing recording progress.
class RecordingProgressRing extends StatelessWidget {
  const RecordingProgressRing({
    super.key,
    required this.clips,
    required this.maxDuration,
    required this.isRecording,
    this.currentRecordingDuration = Duration.zero,
    this.size = 80.0,
    this.strokeWidth = 6.0,
    this.backgroundColor = Colors.white24,
    this.recordingColor = Colors.red,
  });

  /// List of recorded clips.
  final List<RecordedClip> clips;

  /// Maximum total duration.
  final Duration maxDuration;

  /// Whether currently recording.
  final bool isRecording;

  /// Current recording duration (for live updates).
  final Duration currentRecordingDuration;

  /// Size of the ring.
  final double size;

  /// Stroke width of the ring.
  final double strokeWidth;

  /// Background color of the ring.
  final Color backgroundColor;

  /// Color for active recording segment.
  final Color recordingColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ProgressRingPainter(
          clips: clips,
          maxDuration: maxDuration,
          isRecording: isRecording,
          currentRecordingDuration: currentRecordingDuration,
          strokeWidth: strokeWidth,
          backgroundColor: backgroundColor,
          recordingColor: recordingColor,
        ),
        child: Center(
          child: _buildCenterContent(context),
        ),
      ),
    );
  }

  Widget _buildCenterContent(BuildContext context) {
    final totalMs = clips.fold<int>(
          0,
          (sum, clip) => sum + clip.duration.inMilliseconds,
        ) +
        currentRecordingDuration.inMilliseconds;

    final remainingMs = maxDuration.inMilliseconds - totalMs;
    final remainingSecs = (remainingMs / 1000).clamp(0.0, 6.0);

    return Text(
      '${remainingSecs.toStringAsFixed(1)}s',
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.2,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.clips,
    required this.maxDuration,
    required this.isRecording,
    required this.currentRecordingDuration,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.recordingColor,
  });

  final List<RecordedClip> clips;
  final Duration maxDuration;
  final bool isRecording;
  final Duration currentRecordingDuration;
  final double strokeWidth;
  final Color backgroundColor;
  final Color recordingColor;

  // Colors for different clips
  static const List<Color> clipColors = [
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFE91E63), // Pink
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw background ring
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Calculate total angle (full circle = 2π)
    const fullCircle = 2 * math.pi;
    const startAngle = -math.pi / 2; // Start from top

    double currentAngle = startAngle;
    final maxMs = maxDuration.inMilliseconds;

    // Draw each clip's segment
    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final clipAngle = (clip.duration.inMilliseconds / maxMs) * fullCircle;

      final clipPaint = Paint()
        ..color = clipColors[i % clipColors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        clipAngle,
        false,
        clipPaint,
      );

      currentAngle += clipAngle;
    }

    // Draw current recording segment (animated)
    if (isRecording && currentRecordingDuration > Duration.zero) {
      final recordingAngle =
          (currentRecordingDuration.inMilliseconds / maxMs) * fullCircle;

      final recordingPaint = Paint()
        ..color = recordingColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        recordingAngle,
        false,
        recordingPaint,
      );
    }

    // Draw segment dividers
    if (clips.length > 1) {
      double dividerAngle = startAngle;
      final dividerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      for (var i = 0; i < clips.length; i++) {
        final clip = clips[i];
        dividerAngle += (clip.duration.inMilliseconds / maxMs) * fullCircle;

        if (i < clips.length - 1) {
          final x = center.dx + radius * math.cos(dividerAngle);
          final y = center.dy + radius * math.sin(dividerAngle);
          final innerX =
              center.dx + (radius - strokeWidth) * math.cos(dividerAngle);
          final innerY =
              center.dy + (radius - strokeWidth) * math.sin(dividerAngle);

          canvas.drawLine(
            Offset(innerX, innerY),
            Offset(x, y),
            dividerPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return clips != oldDelegate.clips ||
        isRecording != oldDelegate.isRecording ||
        currentRecordingDuration != oldDelegate.currentRecordingDuration;
  }
}
