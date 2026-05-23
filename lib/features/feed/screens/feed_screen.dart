import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:glance_app/core/theme/glance_theme.dart';
import 'package:glance_app/core/providers/providers.dart';
import 'package:glance_app/features/feed/widgets/photo_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGroup = ref.watch(activeGroupProvider).value;
    final photosAsync = ref.watch(activeGroupPhotosProvider);

    return Scaffold(
      backgroundColor: GlanceTheme.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Feed', style: GlanceTheme.displayMedium),
                    if (activeGroup != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: GlanceTheme.primarySurface,
                          borderRadius: BorderRadius.circular(GlanceTheme.radiusFull),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.group_work_rounded, color: GlanceTheme.primary, size: 14),
                            const Gap(6),
                            Text(
                              activeGroup.name,
                              style: GlanceTheme.labelSmall.copyWith(color: GlanceTheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Photos Stream List
              Expanded(
                child: photosAsync.when(
                  data: (photos) {
                    if (photos.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(activeGroupPhotosProvider);
                        },
                        color: GlanceTheme.primary,
                        backgroundColor: GlanceTheme.surfaceElevated,
                        child: ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                            const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.photo_outlined, size: 64, color: GlanceTheme.textTertiary),
                                  Gap(16),
                                  Text(
                                    'No moments shared yet',
                                    style: TextStyle(fontSize: 18, color: GlanceTheme.textSecondary, fontWeight: FontWeight.bold),
                                  ),
                                  Gap(8),
                                  Text(
                                    'Snap a picture to share with this group!',
                                    style: TextStyle(fontSize: 14, color: GlanceTheme.textTertiary),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(activeGroupPhotosProvider);
                      },
                      color: GlanceTheme.primary,
                      backgroundColor: GlanceTheme.surfaceElevated,
                      child: ListView.builder(
                        itemCount: photos.length,
                        itemBuilder: (context, index) {
                          final photo = photos[index];
                          return PhotoCard(photo: photo);
                        },
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: GlanceTheme.primary),
                  ),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: GlanceTheme.error),
                        const Gap(16),
                        Text('Failed to load feed', style: GlanceTheme.titleMedium),
                        const Gap(8),
                        Text(err.toString(), style: GlanceTheme.bodyMedium, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
