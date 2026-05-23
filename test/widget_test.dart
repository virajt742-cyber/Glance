import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glance_app/core/models/models.dart';
import 'package:glance_app/core/providers/providers.dart';

void main() {
  group('UserModel Tests', () {
    test('UserModel.fromJson serialization and deserialization', () {
      final now = DateTime.now();
      final json = {
        'id': 'user-123',
        'displayName': 'Test User',
        'email': 'test@example.com',
        'profilePicUrl': 'https://example.com/pic.jpg',
        'pushToken': 'fcm-token-123',
        'createdAt': now.toIso8601String(),
        'blockedUsers': ['blocked-1', 'blocked-2'],
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 'user-123');
      expect(user.displayName, 'Test User');
      expect(user.email, 'test@example.com');
      expect(user.profilePicUrl, 'https://example.com/pic.jpg');
      expect(user.pushToken, 'fcm-token-123');
      expect(user.blockedUsers, ['blocked-1', 'blocked-2']);
    });

    test('UserModel.copyWith copies fields correctly', () {
      final user = UserModel(
        id: 'user-123',
        displayName: 'Test User',
        email: 'test@example.com',
        createdAt: DateTime.now(),
        blockedUsers: const ['blocked-1'],
      );

      final updatedUser = user.copyWith(
        displayName: 'Updated Name',
        blockedUsers: ['blocked-1', 'blocked-2'],
      );

      expect(updatedUser.id, 'user-123');
      expect(updatedUser.displayName, 'Updated Name');
      expect(updatedUser.blockedUsers, ['blocked-1', 'blocked-2']);
    });
  });

  group('PhotoModel Tests', () {
    test('PhotoModel reactions aggregation', () {
      final photo = PhotoModel(
        id: 'photo-123',
        groupId: 'group-123',
        senderId: 'user-abc',
        storageUrl: 'https://example.com/photo.jpg',
        localTimestamp: DateTime.now(),
        reactionEmojiMap: const {
          'user1': '❤️',
          'user2': '🔥',
          'user3': '🔥',
        },
      );

      expect(photo.reactionCount, 3);
      expect(photo.hasReactedWith('user1'), true);
      expect(photo.getReaction('user1'), '❤️');
      expect(photo.getReaction('user3'), '🔥');
      
      final counts = photo.reactionCounts;
      expect(counts['❤️'], 1);
      expect(counts['🔥'], 2);
    });
  });

  group('Riverpod Provider Tests', () {
    test('Initial states of providers are correct', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(activeGroupIdProvider), null);
      expect(container.read(appLifecycleStateProvider), AppLifecycleState.resumed);
      expect(container.read(homePageIndexProvider), 1); // Default to camera (index 1)
      
      final uploadState = container.read(uploadProvider);
      expect(uploadState.status, UploadStatus.idle);
      expect(uploadState.progress, 0.0);
      expect(uploadState.errorMessage, null);
    });

    test('homePageIndexProvider transitions state correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(homePageIndexProvider), 1);
      container.read(homePageIndexProvider.notifier).state = 0;
      expect(container.read(homePageIndexProvider), 0);
      container.read(homePageIndexProvider.notifier).state = 2;
      expect(container.read(homePageIndexProvider), 2);
    });

    test('UploadNotifier transitions states correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(uploadProvider.notifier);
      expect(container.read(uploadProvider).status, UploadStatus.idle);

      notifier.reset();
      expect(container.read(uploadProvider).status, UploadStatus.idle);
    });
  });
}
