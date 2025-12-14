// ABOUTME: State model for a Vine-style multi-clip recording session.
// ABOUTME: Manages clips, duration budget, and provides operations for reorder/delete.

import 'package:flutter/foundation.dart';

import 'recorded_clip.dart';

/// Manages the state of a Vine-style multi-clip recording session.
class RecordingSession extends ChangeNotifier {
  RecordingSession({
    this.maxDuration = const Duration(seconds: 6),
    this.minClipDuration = const Duration(milliseconds: 500),
  });

  /// Maximum total duration for all clips combined.
  final Duration maxDuration;

  /// Minimum duration for a single clip.
  final Duration minClipDuration;

  /// List of recorded clips in order.
  final List<RecordedClip> _clips = [];

  /// Current recording state.
  RecordingState _state = RecordingState.idle;

  /// Index of clip being re-recorded (null if not re-recording).
  int? _rerecordingIndex;

  // --- Getters ---

  /// Unmodifiable list of clips.
  List<RecordedClip> get clips => List.unmodifiable(_clips);

  /// Current recording state.
  RecordingState get state => _state;

  /// Index of clip being re-recorded.
  int? get rerecordingIndex => _rerecordingIndex;

  /// Whether currently re-recording a specific clip.
  bool get isRerecording => _rerecordingIndex != null;

  /// Total duration of all clips.
  Duration get totalDuration => _clips.fold(
        Duration.zero,
        (sum, clip) => sum + clip.duration,
      );

  /// Remaining time available for recording.
  Duration get remainingTime {
    final remaining = maxDuration - totalDuration;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Progress as a value from 0.0 to 1.0.
  double get progress {
    if (maxDuration.inMilliseconds == 0) return 0.0;
    return (totalDuration.inMilliseconds / maxDuration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  /// Whether more recording time is available.
  bool get canRecordMore => remainingTime > minClipDuration;

  /// Whether there are clips to edit.
  bool get canProceedToEdit => _clips.isNotEmpty;

  /// Whether currently recording.
  bool get isRecording => _state == RecordingState.recording;

  /// Number of clips.
  int get clipCount => _clips.length;

  // --- Mutations ---

  /// Start recording a new clip.
  void startRecording() {
    if (!canRecordMore && !isRerecording) return;
    _state = RecordingState.recording;
    notifyListeners();
  }

  /// Stop recording and add the clip.
  void stopRecording(RecordedClip clip) {
    if (_state != RecordingState.recording) return;

    if (isRerecording && _rerecordingIndex != null) {
      // Replace the clip being re-recorded
      final index = _rerecordingIndex!;
      if (index < _clips.length) {
        _clips[index] = clip;
      }
      _rerecordingIndex = null;
    } else {
      // Add new clip
      _clips.add(clip);
    }

    _state = RecordingState.idle;
    notifyListeners();
  }

  /// Cancel current recording without saving.
  void cancelRecording() {
    _state = RecordingState.idle;
    _rerecordingIndex = null;
    notifyListeners();
  }

  /// Start re-recording a specific clip.
  void startRerecording(int index) {
    if (index < 0 || index >= _clips.length) return;
    _rerecordingIndex = index;
    notifyListeners();
  }

  /// Cancel re-recording mode.
  void cancelRerecording() {
    _rerecordingIndex = null;
    notifyListeners();
  }

  /// Delete a clip at the given index.
  void deleteClip(int index) {
    if (index < 0 || index >= _clips.length) return;
    _clips.removeAt(index);
    notifyListeners();
  }

  /// Reorder clips by moving from oldIndex to newIndex.
  void reorderClips(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _clips.length) return;
    if (newIndex < 0 || newIndex > _clips.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final clip = _clips.removeAt(oldIndex);
    _clips.insert(newIndex, clip);
    notifyListeners();
  }

  /// Update thumbnail for a clip.
  void updateThumbnail(String clipId, Uint8List thumbnail) {
    final index = _clips.indexWhere((c) => c.id == clipId);
    if (index == -1) return;

    _clips[index] = _clips[index].copyWith(thumbnail: thumbnail);
    notifyListeners();
  }

  /// Clear all clips and reset session.
  void reset() {
    _clips.clear();
    _state = RecordingState.idle;
    _rerecordingIndex = null;
    notifyListeners();
  }

  /// Enter preview mode.
  void enterPreview() {
    _state = RecordingState.previewing;
    notifyListeners();
  }

  /// Exit preview mode.
  void exitPreview() {
    _state = RecordingState.idle;
    notifyListeners();
  }
}

/// Possible states for the recording session.
enum RecordingState {
  /// Not recording, waiting for user action.
  idle,

  /// Actively recording video.
  recording,

  /// Previewing the assembled clips.
  previewing,

  /// Processing/stitching clips.
  processing,
}
