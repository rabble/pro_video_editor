// ABOUTME: Model representing a single recorded video clip in a Vine-style session.
// ABOUTME: Tracks file path, duration, thumbnail, and metadata for each segment.

import 'dart:typed_data';

/// Represents a single recorded video clip segment.
class RecordedClip {
  /// Creates a [RecordedClip] instance.
  RecordedClip({
    required this.id,
    required this.filePath,
    required this.duration,
    this.thumbnail,
    DateTime? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now();

  /// Unique identifier for this clip.
  final String id;

  /// Path to the temporary video file.
  final String filePath;

  /// Duration of this clip.
  final Duration duration;

  /// First frame thumbnail for preview (optional).
  final Uint8List? thumbnail;

  /// When this clip was recorded.
  final DateTime recordedAt;

  /// Creates a copy with optional field overrides.
  RecordedClip copyWith({
    String? id,
    String? filePath,
    Duration? duration,
    Uint8List? thumbnail,
    DateTime? recordedAt,
  }) {
    return RecordedClip(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      thumbnail: thumbnail ?? this.thumbnail,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecordedClip && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
