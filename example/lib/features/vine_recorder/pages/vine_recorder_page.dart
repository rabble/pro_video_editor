// ABOUTME: Main Vine-style video recorder page with multi-clip capture.
// ABOUTME: Supports tap-to-record, reorder, delete, re-record, and preview before editing.

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../models/recorded_clip.dart';
import '../models/recording_session.dart';
import '../services/clip_stitcher.dart';
import '../widgets/clip_strip.dart';
import '../widgets/record_button.dart';
import '../widgets/recording_progress_ring.dart';
import '../../editor/pages/video_editor_basic_example_page.dart';

/// Vine-style multi-clip video recorder page.
class VineRecorderPage extends StatefulWidget {
  const VineRecorderPage({super.key});

  @override
  State<VineRecorderPage> createState() => _VineRecorderPageState();
}

class _VineRecorderPageState extends State<VineRecorderPage>
    with WidgetsBindingObserver {
  // Camera
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isCameraInitialized = false;

  // Recording session
  final RecordingSession _session = RecordingSession();

  // Recording state
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  Duration _currentRecordingDuration = Duration.zero;
  String? _currentRecordingPath;

  // Preview
  VideoPlayerController? _previewController;
  String? _stitchedPreviewPath;

  // Processing
  bool _isProcessing = false;

  // UUID generator
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _previewController?.dispose();
    _recordingTimer?.cancel();
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('No cameras available');
        return;
      }

      await _setupCamera(_cameras[_currentCameraIndex]);
    } catch (e) {
      _showError('Failed to initialize camera: $e');
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    _cameraController?.dispose();

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      await _cameraController!.prepareForVideoRecording();
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      _showError('Camera error: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    if (_session.isRecording) return;

    HapticFeedback.lightImpact();

    setState(() => _isCameraInitialized = false);
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _setupCamera(_cameras[_currentCameraIndex]);
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (_session.isRecording) return;
    if (!_session.canRecordMore && !_session.isRerecording) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/clip_$timestamp.mp4';

      await _cameraController!.startVideoRecording();

      _recordingStartTime = DateTime.now();
      _session.startRecording();

      // Start timer to update duration
      _recordingTimer = Timer.periodic(
        const Duration(milliseconds: 50),
        _updateRecordingDuration,
      );
    } catch (e) {
      _showError('Failed to start recording: $e');
    }
  }

  void _updateRecordingDuration(Timer timer) {
    if (_recordingStartTime == null) return;

    final elapsed = DateTime.now().difference(_recordingStartTime!);
    setState(() => _currentRecordingDuration = elapsed);

    // Auto-stop if we've reached the limit
    final totalWithCurrent = _session.totalDuration + elapsed;
    if (totalWithCurrent >= _session.maxDuration) {
      _stopRecording();
    }
  }

  Future<void> _stopRecording() async {
    if (!_session.isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      final xFile = await _cameraController!.stopVideoRecording();

      // Move to our temp path
      if (_currentRecordingPath != null) {
        await File(xFile.path).copy(_currentRecordingPath!);
        await File(xFile.path).delete();
      }

      final duration = _currentRecordingDuration;

      // Only save if clip is long enough
      if (duration >= _session.minClipDuration) {
        final clip = RecordedClip(
          id: _uuid.v4(),
          filePath: _currentRecordingPath!,
          duration: duration,
        );

        _session.stopRecording(clip);

        // Generate thumbnail async
        _generateThumbnail(clip);
      } else {
        _session.cancelRecording();
        // Delete short clip
        try {
          await File(_currentRecordingPath!).delete();
        } catch (_) {}
      }
    } catch (e) {
      _session.cancelRecording();
      _showError('Failed to stop recording: $e');
    }

    _currentRecordingPath = null;
    _recordingStartTime = null;
    setState(() => _currentRecordingDuration = Duration.zero);
  }

  Future<void> _generateThumbnail(RecordedClip clip) async {
    try {
      final thumbnails = await ProVideoEditor.instance.getThumbnails(
        ThumbnailConfigs(
          video: EditorVideo.file(File(clip.filePath)),
          outputSize: const Size(200, 200),
          boxFit: ThumbnailBoxFit.cover,
          timestamps: [Duration.zero],
          outputFormat: ThumbnailFormat.jpeg,
        ),
      );

      if (thumbnails.isNotEmpty) {
        _session.updateThumbnail(clip.id, thumbnails.first);
      }
    } catch (e) {
      debugPrint('Failed to generate thumbnail: $e');
    }
  }

  Future<void> _startPreview() async {
    if (_session.clips.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // Stitch clips
      _stitchedPreviewPath = await ClipStitcher.stitchClips(_session.clips);

      // Initialize video player
      _previewController = VideoPlayerController.file(
        File(_stitchedPreviewPath!),
      );
      await _previewController!.initialize();
      await _previewController!.setLooping(true);
      await _previewController!.play();

      _session.enterPreview();
    } catch (e) {
      _showError('Failed to create preview: $e');
    }

    setState(() => _isProcessing = false);
  }

  void _exitPreview() {
    _previewController?.dispose();
    _previewController = null;
    _session.exitPreview();
  }

  Future<void> _proceedToEditor() async {
    if (_session.clips.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // Stitch if not already done
      final stitchedPath =
          _stitchedPreviewPath ?? await ClipStitcher.stitchClips(_session.clips);

      if (!mounted) return;

      // Navigate to editor
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _VineEditorPage(videoPath: stitchedPath),
        ),
      );

      // Reset session after returning
      _session.reset();
      _stitchedPreviewPath = null;
    } catch (e) {
      _showError('Failed to process video: $e');
    }

    setState(() => _isProcessing = false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview or video preview
            _buildMainContent(),

            // Top bar
            _buildTopBar(),

            // Bottom controls
            _buildBottomControls(),

            // Processing overlay
            if (_isProcessing) _buildProcessingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_session.state == RecordingState.previewing &&
        _previewController != null) {
      return _buildVideoPreview();
    }
    return _buildCameraPreview();
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _cameraController!.value.aspectRatio,
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Center(
      child: AspectRatio(
        aspectRatio: _previewController!.value.aspectRatio,
        child: VideoPlayer(_previewController!),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Close button
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),

            // Progress ring
            RecordingProgressRing(
              clips: _session.clips,
              maxDuration: _session.maxDuration,
              isRecording: _session.isRecording,
              currentRecordingDuration: _currentRecordingDuration,
              size: 50,
              strokeWidth: 4,
            ),

            // Flip camera button
            if (_session.state != RecordingState.previewing)
              IconButton(
                icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                onPressed: _session.isRecording ? null : _flipCamera,
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Clip strip
            if (_session.state != RecordingState.previewing)
              ClipStrip(
                clips: _session.clips,
                selectedIndex: _session.rerecordingIndex,
                onReorder: _session.reorderClips,
                onDelete: _session.deleteClip,
                onRerecord: (index) {
                  _session.startRerecording(index);
                },
              ),

            const SizedBox(height: 20),

            // Main controls
            _buildMainControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainControls() {
    if (_session.state == RecordingState.previewing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Back to recording
          _buildControlButton(
            icon: Icons.arrow_back,
            label: 'Back',
            onTap: _exitPreview,
          ),

          // Continue to editor
          _buildControlButton(
            icon: Icons.check,
            label: 'Edit',
            onTap: _proceedToEditor,
            isPrimary: true,
          ),
        ],
      );
    }

    // Re-recording mode
    if (_session.isRerecording) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.close,
            label: 'Cancel',
            onTap: _session.cancelRerecording,
          ),
          RecordButton(
            isRecording: _session.isRecording,
            canRecord: true,
            onRecordStart: _startRecording,
            onRecordStop: _stopRecording,
          ),
          const SizedBox(width: 80), // Spacer
        ],
      );
    }

    // Normal recording mode
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Preview button
        _buildControlButton(
          icon: Icons.play_arrow,
          label: 'Preview',
          onTap: _session.canProceedToEdit ? _startPreview : null,
        ),

        // Record button
        RecordButton(
          isRecording: _session.isRecording,
          canRecord: _session.canRecordMore,
          onRecordStart: _startRecording,
          onRecordStop: _stopRecording,
        ),

        // Next button
        _buildControlButton(
          icon: Icons.arrow_forward,
          label: 'Next',
          onTap: _session.canProceedToEdit ? _proceedToEditor : null,
          isPrimary: _session.canProceedToEdit,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isPrimary = false,
  }) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isPrimary
                  ? Colors.white
                  : (isEnabled ? Colors.white24 : Colors.white10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isPrimary
                  ? Colors.black
                  : (isEnabled ? Colors.white : Colors.white30),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isEnabled ? Colors.white : Colors.white30,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Processing...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper page that loads the stitched video into pro_image_editor.
class _VineEditorPage extends StatefulWidget {
  const _VineEditorPage({required this.videoPath});

  final String videoPath;

  @override
  State<_VineEditorPage> createState() => _VineEditorPageState();
}

class _VineEditorPageState extends State<_VineEditorPage> {
  @override
  Widget build(BuildContext context) {
    // For now, show a placeholder - full integration with pro_image_editor
    // requires more setup similar to VideoEditorBasicExamplePage
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Edit Your Vine'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_library,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              'Video ready at:\n${widget.videoPath}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to the actual editor
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VideoEditorBasicExamplePage(),
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Open Editor'),
            ),
          ],
        ),
      ),
    );
  }
}
