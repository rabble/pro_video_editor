# divine.video Video Editor Integration Design

## Overview

divine.video is bringing back Vine-style 6-second looping videos. Users capture multiple short clips (tap-to-record), assemble them, then add text/stickers/filters before posting.

This design uses:
- **Custom multi-clip capture UI** for the Vine-style recording experience
- **FFmpeg** for stitching clips together
- **pro_image_editor** (v11.14.1) for the editing UI (text, stickers, filters)
- **pro_video_editor** (v0.4.0) for native rendering, with FFmpeg fallback

### Goals

- Vine-style multi-clip capture (tap to record segments, 6 seconds total)
- Reorder, delete, and re-record individual clips
- Add text, stickers, filters, crop/rotate to the assembled video
- Ship on iOS + Android
- Maintain reliability with FFmpeg fallback

### Non-Goals

- Full timeline editing with per-clip effects
- Audio track mixing/music addition (future consideration)
- Desktop/web support (mobile-first)

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      divine.video App                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              PHASE 1: CAPTURE & ASSEMBLY                   │ │
│  │                    (Custom UI)                             │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │ │
│  │  │ Clip 1   │  │ Clip 2   │  │ Clip 3   │  ...            │ │
│  │  │ 2.1s     │  │ 1.8s     │  │ 2.1s     │                 │ │
│  │  └──────────┘  └──────────┘  └──────────┘                 │ │
│  │       ↕ reorder    ✕ delete    🔄 re-record               │ │
│  └────────────────────────┬───────────────────────────────────┘ │
│                           │                                      │
│                           ▼                                      │
│                 ┌─────────────────┐                             │
│                 │  FFmpeg Stitch  │                             │
│                 │  (concat clips) │                             │
│                 └────────┬────────┘                             │
│                          │                                       │
│                          ▼                                       │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              PHASE 2: EDIT                                 │ │
│  │                 pro_image_editor                           │ │
│  │  ┌─────────────────────────────────────────────────────┐  │ │
│  │  │  • Text overlays                                    │  │ │
│  │  │  • Stickers / emoji                                 │  │ │
│  │  │  • Filters (color matrices)                         │  │ │
│  │  │  • Crop / rotate                                    │  │ │
│  │  │  • Fine trim (if needed)                            │  │ │
│  │  └─────────────────────────────────────────────────────┘  │ │
│  └────────────────────────┬───────────────────────────────────┘ │
│                           │                                      │
│                           ▼                                      │
│                   CompleteParameters                             │
│                           │                                      │
│            ┌──────────────┴──────────────┐                      │
│            ▼                             ▼                       │
│  ┌─────────────────┐          ┌─────────────────┐               │
│  │ pro_video_editor│          │     FFmpeg      │               │
│  │ (native, fast)  │◀─fallback│   (reliable)    │               │
│  └────────┬────────┘          └────────┬────────┘               │
│           │                            │                         │
│           └────────────┬───────────────┘                        │
│                        ▼                                         │
│                   Output MP4                                     │
│                        │                                         │
│                        ▼                                         │
│              ┌─────────────────┐                                │
│              │     Upload      │                                │
│              └─────────────────┘                                │
└──────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Capture & Assembly (Custom)

This is the Vine-style recording experience. You'll build this UI yourself.

### State Model

```dart
class DivineRecordingSession {
  final List<RecordedClip> clips;
  final Duration maxDuration = Duration(seconds: 6);

  Duration get totalDuration => clips.fold(
    Duration.zero,
    (sum, clip) => sum + clip.duration
  );

  Duration get remainingTime => maxDuration - totalDuration;
  bool get canRecordMore => remainingTime > Duration.zero;
  bool get canProceedToEdit => clips.isNotEmpty;
}

class RecordedClip {
  final String id;
  final String filePath;      // temp file
  final Duration duration;
  final Uint8List? thumbnail; // first frame for preview
  final DateTime recordedAt;
}
```

### Capture UI Features

| Feature | Description |
|---------|-------------|
| **Progress ring** | Shows 6-second total, fills as clips accumulate |
| **Tap-to-record** | Hold or tap to record a segment |
| **Clip strip** | Horizontal list of recorded clips with thumbnails |
| **Reorder** | Drag clips to rearrange |
| **Delete** | Swipe or tap X to remove a clip |
| **Re-record** | Tap clip → option to replace it |
| **Preview** | Play assembled clips before proceeding |

### Stitching with FFmpeg

Once the user is happy with their clips, concatenate them:

```dart
Future<String> stitchClips(List<RecordedClip> clips) async {
  // Create concat file
  final concatFile = await _createConcatFile(clips);

  // FFmpeg concat demuxer (fast, no re-encoding if same format)
  final outputPath = '${tempDir}/stitched_${timestamp}.mp4';

  await FFmpegKit.execute(
    '-f concat -safe 0 -i ${concatFile.path} '
    '-c copy '  // no re-encoding = fast
    '$outputPath'
  );

  return outputPath;
}

Future<File> _createConcatFile(List<RecordedClip> clips) async {
  final content = clips
    .map((c) => "file '${c.filePath}'")
    .join('\n');

  final file = File('${tempDir}/concat.txt');
  await file.writeAsString(content);
  return file;
}
```

**Note:** If clips have different codecs/resolutions (e.g., front vs back camera), you'll need to re-encode. For Vine-style UX, enforce consistent capture settings to allow fast `-c copy` concatenation.

---

## Phase 2: Edit (pro_image_editor)

Once clips are stitched, the video goes into `pro_image_editor` for visual editing.

### Integration Flow

```dart
// After stitching clips
final stitchedPath = await ClipStitcher.stitchClips(session.clips);

// Get metadata
final metadata = await ProVideoEditor.instance.getMetadata(
  EditorVideo.file(File(stitchedPath)),
);

// Generate thumbnails for trim bar
final thumbnails = await ProVideoEditor.instance.getThumbnails(...);

// Create video controller
final controller = ProVideoController(
  videoPlayer: VideoPlayer(videoPlayerController),
  videoDuration: metadata.duration,
  initialResolution: metadata.resolution,
  fileSize: metadata.fileSize,
  thumbnails: thumbnails,
);

// Launch editor
ProImageEditor.video(
  controller,
  callbacks: ProImageEditorCallbacks(
    onCompleteWithParameters: (params) => renderVideo(params),
  ),
  configs: ProImageEditorConfigs(
    videoEditor: VideoEditorConfigs(
      maxTrimDuration: Duration(seconds: 6),
    ),
  ),
);
```

### Available Editing Features

| Feature | Description |
|---------|-------------|
| **Text** | Add text with fonts, colors, shadows |
| **Stickers** | Emoji and custom sticker overlays |
| **Drawing** | Freehand paint, shapes, arrows |
| **Filters** | Instagram-style color filters |
| **Crop/Rotate** | Aspect ratio adjustment |
| **Trim** | Fine-tune start/end (within 6s limit) |

---

## Phase 3: Render (Native + FFmpeg Fallback)

### Render Strategy

```dart
Future<String> renderVideo(CompleteParameters params) async {
  final model = RenderVideoModel(
    video: EditorVideo.file(File(stitchedVideoPath)),
    outputFormat: VideoOutputFormat.mp4,
    enableAudio: true,
    imageBytes: params.layers.isNotEmpty ? params.image : null,
    blur: params.blur,
    colorMatrixList: params.colorFilters,
    startTime: params.startTime,
    endTime: params.endTime,
    transform: params.isTransformed ? ExportTransform(...) : null,
  );

  try {
    // Try native renderer first (faster)
    return await ProVideoEditor.instance.renderVideoToFile(
      outputPath,
      model,
    );
  } catch (e) {
    // Fallback to FFmpeg
    return await _renderWithFFmpeg(params);
  }
}
```

### FFmpeg Fallback Implementation

```dart
Future<String> _renderWithFFmpeg(CompleteParameters params) async {
  final filters = <String>[];

  // Trim
  final ssArg = params.startTime != null
    ? '-ss ${params.startTime!.inMilliseconds / 1000}'
    : '';
  final tArg = params.endTime != null && params.startTime != null
    ? '-t ${(params.endTime! - params.startTime!).inMilliseconds / 1000}'
    : '';

  // Transform filters
  if (params.flipX) filters.add('hflip');
  if (params.flipY) filters.add('vflip');
  if (params.rotateTurns > 0) {
    filters.add('transpose=${params.rotateTurns}');
  }
  if (params.cropWidth != null) {
    filters.add('crop=${params.cropWidth}:${params.cropHeight}:${params.cropX}:${params.cropY}');
  }

  // Color filter (4x5 matrix to FFmpeg colormatrix)
  if (params.colorFilters.isNotEmpty) {
    // Convert to FFmpeg eq/colormatrix filter
    filters.add(_buildColorFilter(params.colorFiltersCombined));
  }

  // Overlay (text, stickers flattened to PNG)
  String overlayInput = '';
  String overlayFilter = '';
  if (params.layers.isNotEmpty) {
    await File(overlayPath).writeAsBytes(params.image);
    overlayInput = '-i $overlayPath';
    overlayFilter = 'overlay=0:0';
  }

  final filterComplex = filters.isNotEmpty
    ? '-vf "${filters.join(',')}"'
    : '';

  await FFmpegKit.execute(
    '$ssArg -i $inputPath $overlayInput $tArg $filterComplex -c:a copy $outputPath'
  );

  return outputPath;
}
```

---

## Implementation Summary

### Files Created (Example App)

```
example/lib/features/vine_recorder/
├── models/
│   ├── recorded_clip.dart      # Single clip model
│   └── recording_session.dart  # Session state management
├── services/
│   └── clip_stitcher.dart      # FFmpeg concat service
├── widgets/
│   ├── recording_progress_ring.dart  # Circular 6s progress
│   ├── clip_strip.dart               # Reorderable clip thumbnails
│   └── record_button.dart            # Animated record button
├── pages/
│   └── vine_recorder_page.dart       # Main recorder screen
└── vine_recorder.dart                # Barrel exports
```

### Dependencies Added

```yaml
camera: ^0.11.1           # Video capture
ffmpeg_kit_flutter: ^6.0.3  # Clip stitching
uuid: ^4.5.1              # Clip IDs
```

### iOS Permissions (Info.plist)

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to record Vine-style videos.</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record audio.</string>
```

---

## Known Limitations & Future Work

### Current Limitations

1. **No per-clip effects** - Effects apply to stitched video, not individual clips
2. **No music/audio mixing** - Original audio only
3. **6-second hard limit** - Matches Vine, but could be configurable

### Future Enhancements

1. **Music library** - Add background tracks
2. **Speed ramping** - Slow-mo and fast-forward per clip
3. **Transitions** - Cross-fade between clips
4. **AR filters** - Real-time face filters during capture

---

## Testing Checklist

- [ ] Record single clip → edit → export
- [ ] Record multiple clips → reorder → edit → export
- [ ] Delete clip mid-session
- [ ] Re-record specific clip
- [ ] Preview before editing
- [ ] Text overlay renders correctly
- [ ] Filter applies to full video
- [ ] Trim within editor works
- [ ] FFmpeg fallback triggers on native failure
- [ ] Front/back camera switching

