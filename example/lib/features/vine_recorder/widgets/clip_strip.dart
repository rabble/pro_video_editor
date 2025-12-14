// ABOUTME: Horizontal strip showing recorded clips with thumbnails.
// ABOUTME: Supports drag-to-reorder, swipe-to-delete, and tap-to-rerecord.

import 'package:flutter/material.dart';

import '../models/recorded_clip.dart';

/// Horizontal strip of clip thumbnails with reorder/delete support.
class ClipStrip extends StatelessWidget {
  const ClipStrip({
    super.key,
    required this.clips,
    required this.onReorder,
    required this.onDelete,
    required this.onRerecord,
    this.selectedIndex,
    this.clipSize = 60.0,
  });

  /// List of recorded clips.
  final List<RecordedClip> clips;

  /// Callback when clips are reordered.
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Callback when a clip is deleted.
  final void Function(int index) onDelete;

  /// Callback when user wants to re-record a clip.
  final void Function(int index) onRerecord;

  /// Index of currently selected/re-recording clip.
  final int? selectedIndex;

  /// Size of each clip thumbnail.
  final double clipSize;

  @override
  Widget build(BuildContext context) {
    if (clips.isEmpty) {
      return SizedBox(
        height: clipSize + 20,
        child: const Center(
          child: Text(
            'Tap and hold to record',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return SizedBox(
      height: clipSize + 20,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        proxyDecorator: _proxyDecorator,
        itemCount: clips.length,
        onReorder: onReorder,
        itemBuilder: (context, index) {
          return _ClipThumbnail(
            key: ValueKey(clips[index].id),
            clip: clips[index],
            index: index,
            isSelected: selectedIndex == index,
            size: clipSize,
            onDelete: () => onDelete(index),
            onRerecord: () => onRerecord(index),
          );
        },
      ),
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = Tween<double>(begin: 1.0, end: 1.1).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
        );
        return Transform.scale(
          scale: scale.value,
          child: child,
        );
      },
      child: child,
    );
  }
}

class _ClipThumbnail extends StatelessWidget {
  const _ClipThumbnail({
    super.key,
    required this.clip,
    required this.index,
    required this.isSelected,
    required this.size,
    required this.onDelete,
    required this.onRerecord,
  });

  final RecordedClip clip;
  final int index;
  final bool isSelected;
  final double size;
  final VoidCallback onDelete;
  final VoidCallback onRerecord;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ReorderableDragStartListener(
        index: index,
        child: GestureDetector(
          onTap: () => _showClipOptions(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.red : Colors.white38,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Thumbnail or placeholder
                  _buildThumbnail(),

                  // Duration badge
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(clip.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Clip number
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Re-record indicator
                  if (isSelected)
                    Container(
                      color: Colors.red.withValues(alpha: 0.3),
                      child: const Center(
                        child: Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (clip.thumbnail != null) {
      return Image.memory(
        clip.thumbnail!,
        fit: BoxFit.cover,
      );
    }

    // Placeholder with gradient
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getClipColor(index),
            _getClipColor(index).withValues(alpha: 0.6),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.videocam,
          color: Colors.white54,
          size: 24,
        ),
      ),
    );
  }

  Color _getClipColor(int index) {
    const colors = [
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
      Color(0xFFFF9800),
      Color(0xFF9C27B0),
      Color(0xFF00BCD4),
      Color(0xFFE91E63),
    ];
    return colors[index % colors.length];
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inMilliseconds / 1000;
    return '${seconds.toStringAsFixed(1)}s';
  }

  void _showClipOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Clip ${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.orange),
                title: const Text(
                  'Re-record',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Replace this clip with a new recording',
                  style: TextStyle(color: Colors.white54),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onRerecord();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Remove this clip',
                  style: TextStyle(color: Colors.white54),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
