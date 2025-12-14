// ABOUTME: Animated record button with press-and-hold or tap-to-toggle recording.
// ABOUTME: Shows visual feedback during recording with pulsing animation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Animated record button for Vine-style recording.
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.isRecording,
    required this.canRecord,
    required this.onRecordStart,
    required this.onRecordStop,
    this.size = 80.0,
  });

  /// Whether currently recording.
  final bool isRecording;

  /// Whether recording is allowed (time remaining).
  final bool canRecord;

  /// Callback when recording starts.
  final VoidCallback onRecordStart;

  /// Callback when recording stops.
  final VoidCallback onRecordStop;

  /// Size of the button.
  final double size;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRecording && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.canRecord ? (_) => _startRecording() : null,
      onTapUp: widget.isRecording ? (_) => _stopRecording() : null,
      onTapCancel: widget.isRecording ? _stopRecording : null,
      onLongPressStart: widget.canRecord ? (_) => _startRecording() : null,
      onLongPressEnd: widget.isRecording ? (_) => _stopRecording() : null,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = widget.isRecording ? _pulseAnimation.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 4,
            ),
            boxShadow: widget.isRecording
                ? [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: widget.isRecording ? Colors.red : Colors.red.shade400,
              shape: widget.isRecording ? BoxShape.rectangle : BoxShape.circle,
              borderRadius:
                  widget.isRecording ? BorderRadius.circular(8) : null,
            ),
            child: widget.canRecord
                ? null
                : const Center(
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _startRecording() {
    HapticFeedback.mediumImpact();
    widget.onRecordStart();
  }

  void _stopRecording() {
    HapticFeedback.lightImpact();
    widget.onRecordStop();
  }
}
