import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glance_app/core/theme/glance_theme.dart';
import 'package:glance_app/core/providers/providers.dart';
import 'package:glance_app/core/constants/app_constants.dart';
import 'package:glance_app/core/models/photo_model.dart';

class EmojiReactionsBar extends ConsumerWidget {
  final PhotoModel photo;

  const EmojiReactionsBar({super.key, required this.photo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const SizedBox.shrink();

    final firestoreService = ref.read(firestoreServiceProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(GlanceTheme.radiusFull),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AppConstants.reactionEmojis.map((emoji) {
          final isReacted = photo.getReaction(userId) == emoji;

          return GestureDetector(
            onTap: () async {
              try {
                if (isReacted) {
                  await firestoreService.removeReaction(
                    photoId: photo.id,
                    userId: userId,
                  );
                } else {
                  await firestoreService.addReaction(
                    photoId: photo.id,
                    userId: userId,
                    emoji: emoji,
                  );
                }
              } catch (e) {
                debugPrint('Failed to update reaction: $e');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isReacted ? GlanceTheme.primarySurface : Colors.transparent,
                borderRadius: BorderRadius.circular(GlanceTheme.radiusSm),
              ),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
