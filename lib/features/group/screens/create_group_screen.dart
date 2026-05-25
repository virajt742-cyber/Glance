import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:glance_app/core/theme/glance_theme.dart';
import 'package:glance_app/core/providers/providers.dart';
import 'package:glance_app/features/auth/widgets/glance_text_field.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _groupNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _statusMessage;

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Generating invite code...';
    });

    Timer? progressTimer;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      progressTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (!mounted || !_isLoading) {
          timer.cancel();
          return;
        }
        setState(() {
          if (timer.tick == 1) {
            _statusMessage = 'Saving group to database...';
          } else if (timer.tick == 2) {
            _statusMessage = 'Checking connection status...';
          } else if (timer.tick >= 3) {
            _statusMessage = 'Still working, waiting for server response...';
          }
        });
      });

      final group = await firestoreService.createGroup(
        name: _groupNameController.text.trim(),
        creatorId: userId,
      );

      // Select this group
      ref.read(activeGroupIdProvider.notifier).state = group.id;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created group "${group.name}"!'),
            backgroundColor: GlanceTheme.success,
          ),
        );
        Navigator.of(context).pop();
      }
    // ERROR FIX: Inform the user to check their Firebase Console database setup when write times out.
    // In FlutterFire, if a write is blocked by security rules (or if the DB doesn't exist),
    // and offline persistence is active, the Future hangs indefinitely. A timeout handles this gracefully.
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request timed out. Please check your network connection and verify that Cloud Firestore is created and enabled in your Firebase Console.'),
            backgroundColor: GlanceTheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create group: $e'),
            backgroundColor: GlanceTheme.error,
          ),
        );
      }
    } finally {
      progressTimer?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlanceTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create new group',
                  style: GlanceTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const Gap(8),
                Text(
                  'Choose a name for your closest circle.',
                  style: GlanceTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Gap(48),

                // Group Name Field
                GlanceTextField(
                  controller: _groupNameController,
                  label: 'Group Name',
                  hint: 'e.g. Besties, Family, Squad',
                  prefixIcon: Icons.group_add_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Group name is required';
                    }
                    if (value.trim().length < 3) {
                      return 'Group name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const Gap(40),

                // Create Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleCreateGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlanceTheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(GlanceTheme.radiusFull),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            'Create Group',
                            style: GlanceTheme.titleMedium.copyWith(color: Colors.black),
                          ),
                  ),
                ),
                if (_isLoading && _statusMessage != null) ...[
                  const Gap(16),
                  Text(
                    _statusMessage!,
                    style: GlanceTheme.bodyMedium.copyWith(
                      color: GlanceTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
