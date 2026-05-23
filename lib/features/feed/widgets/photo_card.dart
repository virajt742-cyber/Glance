import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:glance_app/core/theme/glance_theme.dart';
import 'package:glance_app/core/providers/providers.dart';
import 'package:glance_app/core/models/models.dart';
import 'package:glance_app/features/feed/widgets/emoji_reactions_bar.dart';

class PhotoCard extends ConsumerStatefulWidget {
  final PhotoModel photo;

  const PhotoCard({super.key, required this.photo});

  @override
  ConsumerState<PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends ConsumerState<PhotoCard> {
  bool _showReactionsBar = false;
  Map<String, String> _previousReactions = {};
  final List<_FloatingEmoji> _floatingEmojis = [];
  final _random = math.Random();
  UserModel? _sender;
  StreamSubscription? _photoSub;

  @override
  void initState() {
    super.initState();
    _previousReactions = Map.from(widget.photo.reactionEmojiMap);
    _fetchSender();
    _subscribeToLivePhoto();
  }

  @override
  void dispose() {
    _photoSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchSender() async {
    final authService = ref.read(authServiceProvider);
    final user = await authService.getUserById(widget.photo.senderId);
    if (mounted) {
      setState(() {
        _sender = user;
      });
    }
  }

  void _subscribeToLivePhoto() {
    _photoSub = ref.read(firestoreServiceProvider).photoStream(widget.photo.id).listen((updatedPhoto) {
      if (updatedPhoto == null || !mounted) return;

      // Check if there are new reactions compared to previous
      updatedPhoto.reactionEmojiMap.forEach((userId, emoji) {
        final prevEmoji = _previousReactions[userId];
        if (prevEmoji != emoji) {
          // New reaction detected! Spawn a floating emoji animation
          _spawnFloatingEmoji(emoji);
        }
      });

      _previousReactions = Map.from(updatedPhoto.reactionEmojiMap);
    });
  }

  void _spawnFloatingEmoji(String emoji) {
    setState(() {
      _floatingEmojis.add(
        _FloatingEmoji(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          emoji: emoji,
          x: 0.2 + _random.nextDouble() * 0.6, // Spawn randomly across horizontal axis
        ),
      );
    });
  }

  void _removeFloatingEmoji(String id) {
    if (mounted) {
      setState(() {
        _floatingEmojis.removeWhere((e) => e.id == id);
      });
    }
  }

  Future<void> _handleReportPhoto(BuildContext context) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null || _sender == null) return;

    final reasons = ['Spam', 'Harassment', 'Inappropriate Content', 'Hate Speech', 'Other'];
    String? selectedReason;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: GlanceTheme.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GlanceTheme.radiusXl),
            side: const BorderSide(color: GlanceTheme.borderSubtle, width: 0.5),
          ),
          title: Text(
            'Report Photo',
            style: GlanceTheme.titleLarge.copyWith(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Why are you reporting this photo? We will review it within 24 hours.',
                style: GlanceTheme.bodyMedium.copyWith(color: GlanceTheme.textSecondary),
              ),
              const Gap(16),
              ...reasons.map((reason) => RadioListTile<String>(
                title: Text(reason, style: GlanceTheme.bodyLarge.copyWith(color: Colors.white)),
                value: reason,
                groupValue: selectedReason,
                activeColor: GlanceTheme.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setDialogState(() {
                    selectedReason = val;
                  });
                },
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GlanceTheme.bodyLarge.copyWith(color: GlanceTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GlanceTheme.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GlanceTheme.radiusMd),
                ),
              ),
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      try {
                        await ref.read(firestoreServiceProvider).reportContent(
                          reportedBy: currentUserId,
                          reportedUserId: _sender!.id,
                          photoId: widget.photo.id,
                          reason: selectedReason!,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thank you. The content has been reported and will be reviewed.'),
                              backgroundColor: GlanceTheme.primary,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to report content: $e'),
                              backgroundColor: GlanceTheme.error,
                            ),
                          );
                        }
                      }
                    },
              child: Text('Submit Report', style: GlanceTheme.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBlockUser(BuildContext context) async {
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null || _sender == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GlanceTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlanceTheme.radiusXl),
          side: const BorderSide(color: GlanceTheme.borderSubtle, width: 0.5),
        ),
        title: Text(
          'Block User',
          style: GlanceTheme.titleLarge.copyWith(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to block ${_sender!.displayName}? You will no longer see their photos in your feed.',
          style: GlanceTheme.bodyMedium.copyWith(color: GlanceTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GlanceTheme.bodyLarge.copyWith(color: GlanceTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GlanceTheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GlanceTheme.radiusMd),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Block', style: GlanceTheme.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(firestoreServiceProvider).blockUser(
          blockerId: currentUserId,
          blockedId: _sender!.id,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_sender!.displayName} has been blocked.'),
              backgroundColor: GlanceTheme.primary,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to block user: $e'),
              backgroundColor: GlanceTheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppLifecycleState>(appLifecycleStateProvider, (previous, current) {
      if (current == AppLifecycleState.paused || current == AppLifecycleState.detached) {
        _photoSub?.cancel();
        _photoSub = null;
      } else if (current == AppLifecycleState.resumed) {
        if (_photoSub == null) {
          _subscribeToLivePhoto();
        }
      }
    });

    final livePhotoAsync = ref.watch(photoStreamProvider(widget.photo.id));
    final currentPhoto = livePhotoAsync.value ?? widget.photo;
    final currentUserId = ref.watch(currentUserIdProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: GlanceTheme.surfaceDark,
        borderRadius: BorderRadius.circular(GlanceTheme.radiusXl),
        border: Border.all(color: GlanceTheme.borderSubtle, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header: User Info & Timestamp ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: GlanceTheme.surfaceElevated,
                  backgroundImage: _sender?.profilePicUrl.isNotEmpty == true
                      ? NetworkImage(_sender!.profilePicUrl)
                      : null,
                  child: _sender?.profilePicUrl.isEmpty == true
                      ? Text(
                          _sender?.displayName.characters.firstOrNull?.toUpperCase() ?? 'U',
                          style: const TextStyle(color: GlanceTheme.primary, fontSize: 14),
                        )
                      : null,
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sender?.displayName ?? 'Loading...',
                        style: GlanceTheme.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        timeago.format(currentPhoto.localTimestamp),
                        style: GlanceTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showReactionsBar ? Icons.emoji_emotions_rounded : Icons.emoji_emotions_outlined,
                    color: _showReactionsBar ? GlanceTheme.primary : GlanceTheme.textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      _showReactionsBar = !_showReactionsBar;
                    });
                  },
                ),
                if (_sender != null && _sender!.id != currentUserId) ...[
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: GlanceTheme.textSecondary),
                    color: GlanceTheme.surfaceElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GlanceTheme.radiusMd),
                      side: const BorderSide(color: GlanceTheme.borderSubtle, width: 0.5),
                    ),
                    onSelected: (value) {
                      if (value == 'report') {
                        _handleReportPhoto(context);
                      } else if (value == 'block') {
                        _handleBlockUser(context);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            const Icon(Icons.flag_outlined, color: GlanceTheme.error, size: 20),
                            const Gap(8),
                            Text('Report Photo', style: GlanceTheme.bodyLarge.copyWith(color: GlanceTheme.error)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            const Icon(Icons.block, color: Colors.white, size: 20),
                            const Gap(8),
                            Text('Block User', style: GlanceTheme.bodyLarge.copyWith(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ─── Photo Frame (Square) ───
          GestureDetector(
            onDoubleTap: () {
              setState(() {
                _showReactionsBar = !_showReactionsBar;
              });
            },
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.0,
                  child: CachedNetworkImage(
                    imageUrl: currentPhoto.storageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: GlanceTheme.surfaceElevated,
                      highlightColor: GlanceTheme.borderSubtle,
                      child: Container(color: GlanceTheme.surfaceElevated),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: GlanceTheme.surfaceElevated,
                      child: const Icon(Icons.broken_image_rounded, color: GlanceTheme.error),
                    ),
                  ),
                ),

                // Floating Emojis Layer
                Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      children: _floatingEmojis.map((floating) {
                        return _FloatingEmojiWidget(
                          key: ValueKey(floating.id),
                          floating: floating,
                          onComplete: () => _removeFloatingEmoji(floating.id),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Static Reactions Bar overlay (bottom right)
                if (currentPhoto.reactionEmojiMap.isNotEmpty)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(GlanceTheme.radiusMd),
                        border: Border.all(color: Colors.white10, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: currentPhoto.reactionCounts.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Row(
                              children: [
                                Text(entry.key, style: const TextStyle(fontSize: 14)),
                                if (entry.value > 1) ...[
                                  const Gap(2),
                                  Text(
                                    entry.value.toString(),
                                    style: GlanceTheme.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                // Caption Overlay at the bottom left
                if (currentPhoto.caption.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: GlanceTheme.cameraOverlayGradient,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        currentPhoto.caption,
                        style: GlanceTheme.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ─── Inline Emoji reactions bar if toggled ───
          AnimatedSize(
            duration: 200.ms,
            child: _showReactionsBar
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: EmojiReactionsBar(photo: currentPhoto),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _FloatingEmoji {
  final String id;
  final String emoji;
  final double x; // Horizontal percent (0.0 to 1.0)

  const _FloatingEmoji({
    required this.id,
    required this.emoji,
    required this.x,
  });
}

class _FloatingEmojiWidget extends StatefulWidget {
  final _FloatingEmoji floating;
  final VoidCallback onComplete;

  const _FloatingEmojiWidget({
    super.key,
    required this.floating,
    required this.onComplete,
  });

  @override
  State<_FloatingEmojiWidget> createState() => _FloatingEmojiWidgetState();
}

class _FloatingEmojiWidgetState extends State<_FloatingEmojiWidget> {
  @override
  void initState() {
    super.initState();
    // Auto-remove widget after animation finishes
    Timer(const Duration(milliseconds: 1200), widget.onComplete);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Align(
      alignment: Alignment(widget.floating.x * 2 - 1, 0.8), // Spawn near bottom
      child: Text(
        widget.floating.emoji,
        style: const TextStyle(fontSize: 48),
      )
          .animate()
          .slideY(
            begin: 0.0,
            end: -2.0, // Rise up significantly
            duration: 1200.ms,
            curve: Curves.easeOutQuad,
          )
          .scale(
            begin: const Offset(0.3, 0.3),
            end: const Offset(1.2, 1.2),
            duration: 400.ms,
            curve: Curves.elasticOut,
          )
          .fadeOut(
            delay: 700.ms,
            duration: 500.ms,
          ),
    );
  }
}
