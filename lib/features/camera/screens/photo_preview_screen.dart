import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import 'package:glance_app/core/theme/glance_theme.dart';
import 'package:glance_app/core/providers/providers.dart';
import 'package:glance_app/core/models/group_model.dart';

class PhotoPreviewScreen extends ConsumerStatefulWidget {
  final XFile imageFile;

  const PhotoPreviewScreen({super.key, required this.imageFile});

  @override
  ConsumerState<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends ConsumerState<PhotoPreviewScreen> {
  final _captionController = TextEditingController();
  GroupModel? _selectedGroup;

  @override
  void initState() {
    super.initState();
    // Default to active group
    final activeGroup = ref.read(activeGroupProvider).value;
    if (activeGroup != null) {
      _selectedGroup = activeGroup;
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final group = _selectedGroup;
    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a group first'),
          backgroundColor: GlanceTheme.warning,
        ),
      );
      return;
    }

    final notifier = ref.read(uploadProvider.notifier);
    final success = await notifier.uploadPhoto(
      imagePath: widget.imageFile.path,
      groupId: group.id,
      caption: _captionController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo sent successfully!'),
          backgroundColor: GlanceTheme.success,
        ),
      );
      Navigator.of(context).pop(); // Back to camera
    } else if (mounted) {
      final uploadState = ref.read(uploadProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uploadState.errorMessage ?? 'Failed to send photo'),
          backgroundColor: GlanceTheme.error,
        ),
      );
    }
  }

  void _showGroupSelector() {
    final groupsAsync = ref.read(userGroupsProvider);
    groupsAsync.whenData((groups) {
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select Group',
                  style: GlanceTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const Gap(16),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No groups found. Please create or join a group first.',
                      style: GlanceTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final g = groups[index];
                        return ListTile(
                          title: Text(g.name, style: GlanceTheme.bodyLarge.copyWith(color: GlanceTheme.textPrimary)),
                          trailing: _selectedGroup?.id == g.id
                              ? const Icon(Icons.check_circle_rounded, color: GlanceTheme.primary)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedGroup = g;
                            });
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: uploadState.isUploading ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text('New Post', style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image Preview Card (square)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(GlanceTheme.radiusLg),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: kIsWeb
                          ? Image.network(
                              widget.imageFile.path,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                              ),
                            )
                          : Image.file(
                              File(widget.imageFile.path),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const Gap(24),

                  // Caption Input
                  TextField(
                    controller: _captionController,
                    maxLines: 2,
                    maxLength: 100,
                    style: GlanceTheme.bodyLarge.copyWith(color: GlanceTheme.textPrimary),
                    enabled: !uploadState.isUploading,
                    decoration: InputDecoration(
                      hintText: 'Add a caption...',
                      fillColor: GlanceTheme.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(GlanceTheme.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      counterStyle: const TextStyle(color: GlanceTheme.textTertiary),
                    ),
                  ),
                  const Gap(20),

                  // Group Selector Field
                  GestureDetector(
                    onTap: uploadState.isUploading ? null : _showGroupSelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: GlanceTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(GlanceTheme.radiusMd),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Send to Group',
                                style: GlanceTheme.bodySmall.copyWith(color: GlanceTheme.textTertiary),
                              ),
                              const Gap(4),
                              Text(
                                _selectedGroup?.name ?? 'Select a group',
                                style: GlanceTheme.bodyLarge.copyWith(
                                  color: _selectedGroup != null ? GlanceTheme.primary : GlanceTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: GlanceTheme.textTertiary, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const Gap(40),

                  // Action Buttons
                  ElevatedButton(
                    onPressed: uploadState.isUploading ? null : _handleSend,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: GlanceTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GlanceTheme.radiusFull),
                      ),
                    ),
                    child: Text(
                      'Share Moment',
                      style: GlanceTheme.titleMedium.copyWith(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Uploading loading Overlay
          if (uploadState.isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: GlanceTheme.primary),
                      const Gap(24),
                      Text(
                        _getUploadStatusText(uploadState.status),
                        style: GlanceTheme.headlineMedium.copyWith(color: Colors.white),
                      ),
                      const Gap(8),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: uploadState.progress,
                          backgroundColor: Colors.white10,
                          color: GlanceTheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getUploadStatusText(UploadStatus status) {
    switch (status) {
      case UploadStatus.compressing:
        return 'Compressing photo...';
      case UploadStatus.uploading:
        return 'Uploading to storage...';
      case UploadStatus.saving:
        return 'Saving to database...';
      case UploadStatus.notifying:
        return 'Updating widgets...';
      default:
        return 'Sending...';
    }
  }
}
