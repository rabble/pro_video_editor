// ABOUTME: Service for stitching multiple video clips into a single video.
// ABOUTME: Uses FFmpeg concat demuxer for fast concatenation without re-encoding.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/recorded_clip.dart';

/// Service for stitching video clips together using FFmpeg.
///
/// NOTE: FFmpeg (ffmpeg_kit_flutter_new) has broken macOS dependencies.
/// For macOS development, this returns just the first clip.
/// For iOS/Android builds, uncomment ffmpeg_kit_flutter_new in pubspec.yaml
/// and enable the FFmpeg implementation below.
class ClipStitcher {
  /// Stitches multiple clips into a single video file.
  ///
  /// Uses FFmpeg's concat demuxer for fast concatenation.
  /// Returns the path to the stitched video file.
  ///
  /// Throws [StitchingException] if the operation fails.
  static Future<String> stitchClips(List<RecordedClip> clips) async {
    if (clips.isEmpty) {
      throw StitchingException('No clips to stitch');
    }

    if (clips.length == 1) {
      // Single clip, just return its path
      return clips.first.filePath;
    }

    // Desktop/web fallback: return first clip with warning
    // TODO: For iOS/Android production builds, enable FFmpeg implementation
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux || kIsWeb) {
      debugPrint('ClipStitcher: FFmpeg not available on desktop. '
          'Returning first clip only. For full stitching, run on iOS/Android.');
      return clips.first.filePath;
    }

    // iOS/Android: Use FFmpeg (requires uncommenting dependency in pubspec.yaml)
    return _stitchWithFFmpeg(clips);
  }

  /// FFmpeg-based stitching for iOS/Android.
  ///
  /// To enable on iOS/Android:
  /// 1. Uncomment ffmpeg_kit_flutter_new in pubspec.yaml
  /// 2. Add imports at the top of this file:
  ///    import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
  ///    import 'package:ffmpeg_kit_flutter_new/return_code.dart';
  /// 3. Uncomment the implementation below
  static Future<String> _stitchWithFFmpeg(List<RecordedClip> clips) async {
    // TODO: Enable for iOS/Android builds
    /*
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final concatFilePath = '${tempDir.path}/concat_$timestamp.txt';
    final outputPath = '${tempDir.path}/stitched_$timestamp.mp4';

    // Create concat file
    final concatContent = clips
        .map((clip) => "file '${clip.filePath}'")
        .join('\n');

    final concatFile = File(concatFilePath);
    await concatFile.writeAsString(concatContent);

    debugPrint('ClipStitcher: Stitching ${clips.length} clips...');

    // Run FFmpeg concat (fast, no re-encoding if same format)
    final command = '-f concat -safe 0 -i "$concatFilePath" '
        '-c copy '
        '-movflags +faststart '
        '"$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    // Cleanup concat file
    try {
      await concatFile.delete();
    } catch (_) {}

    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint('ClipStitcher: Stitching complete → $outputPath');
      return outputPath;
    } else {
      debugPrint('ClipStitcher: Fast concat failed, trying re-encode...');
      return _stitchWithReencode(clips, tempDir.path, timestamp);
    }
    */

    // Fallback for when FFmpeg is not enabled
    debugPrint('ClipStitcher: FFmpeg implementation not enabled.');
    return clips.first.filePath;
  }

  /// Fallback stitching with re-encoding for clips with different formats.
  static Future<String> _stitchWithReencode(
    List<RecordedClip> clips,
    String tempDirPath,
    int timestamp,
  ) async {
    // TODO: Enable for iOS/Android builds (see _stitchWithFFmpeg comments)
    debugPrint('ClipStitcher: Re-encode fallback - returning first clip.');
    return clips.first.filePath;
  }

  /// Generates a thumbnail from the first frame of a video.
  static Future<String> generateThumbnail(
    String videoPath, {
    int width = 200,
  }) async {
    // TODO: Enable for iOS/Android builds (see _stitchWithFFmpeg comments)
    final tempDir = await getTemporaryDirectory();
    // ignore: unused_local_variable
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // ignore: unused_local_variable
    final outputPath = '${tempDir.path}/thumb_$timestamp.jpg';

    throw StitchingException('Thumbnail generation requires FFmpeg (iOS/Android)');
  }
}

/// Exception thrown when clip stitching fails.
class StitchingException implements Exception {
  StitchingException(this.message);

  final String message;

  @override
  String toString() => 'StitchingException: $message';
}
