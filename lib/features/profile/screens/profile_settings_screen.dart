import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';

import 'package:glance_app/core/theme/glance_theme.dart';
import 'package:glance_app/core/providers/providers.dart';
import 'package:glance_app/core/models/models.dart';
import 'package:glance_app/features/auth/widgets/glance_text_field.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile != null) {
      _nameController.text = profile.displayName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handlePickAvatar() async {
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (image == null) return;

    setState(() {
      _isUploadingAvatar = true;
      _errorMessage = null;
    });

    try {
      final storageService = ref.read(storageServiceProvider);
      final authService = ref.read(authServiceProvider);
      final String downloadUrl;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        downloadUrl = await storageService.uploadProfilePhotoFromBytes(
          imageBytes: bytes,
          userId: profile.id,
        );
      } else {
        downloadUrl = await storageService.uploadProfilePhoto(
          imageFile: File(image.path),
          userId: profile.id,
        );
      }

      await authService.updateProfile(profilePicUrl: downloadUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar updated successfully!'),
            backgroundColor: GlanceTheme.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to upload avatar: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _handleSaveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.updateProfile(displayName: _nameController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: GlanceTheme.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save profile: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GlanceTheme.surfaceElevated,
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of Glance?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: GlanceTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GlanceTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GlanceTheme.surfaceElevated,
        title: const Text('Delete Account', style: TextStyle(color: GlanceTheme.error)),
        content: const Text(
          'WARNING: This will permanently delete your Glance profile, posts, and group memberships. This action cannot be undone.\n\nAre you absolutely sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: GlanceTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GlanceTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm1 != true) return;

    if (!mounted) return;
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GlanceTheme.surfaceElevated,
        title: const Text('Confirm Account Deletion', style: TextStyle(color: GlanceTheme.error)),
        content: const Text(
          'Please confirm one final time. Tap Delete to delete your account permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go Back', style: TextStyle(color: GlanceTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GlanceTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE PERMANENTLY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm2 == true && mounted) {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });

      try {
        final authService = ref.read(authServiceProvider);
        await authService.deleteAccount();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully.'),
              backgroundColor: GlanceTheme.primary,
            ),
          );
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage!),
              backgroundColor: GlanceTheme.error,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: GlanceTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Settings & Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar Picker Card
                    Center(
                      child: GestureDetector(
                        onTap: _isUploadingAvatar ? null : _handlePickAvatar,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 64,
                              backgroundColor: GlanceTheme.surfaceElevated,
                              backgroundImage: profile.profilePicUrl.isNotEmpty
                                  ? NetworkImage(profile.profilePicUrl)
                                  : null,
                              child: profile.profilePicUrl.isEmpty
                                  ? Text(
                                      profile.displayName.characters.firstOrNull?.toUpperCase() ?? 'U',
                                      style: const TextStyle(fontSize: 48, color: GlanceTheme.primary),
                                    )
                                  : null,
                            ),
                            if (_isUploadingAvatar)
                              Container(
                                width: 128,
                                height: 128,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const CircularProgressIndicator(color: GlanceTheme.primary),
                              )
                            else
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: GlanceTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 20,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(32),

                    // Display Error if any
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: GlanceTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(GlanceTheme.radiusMd),
                          border: Border.all(color: GlanceTheme.error, width: 0.5),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: GlanceTheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Gap(24),
                    ],

                    // Email Read-only Card
                    GlanceTextField(
                      controller: TextEditingController(text: profile.email),
                      label: 'Email (Read-Only)',
                      hint: '',
                      prefixIcon: Icons.email_outlined,
                      enabled: false,
                    ),
                    const Gap(16),

                    // Display Name Input
                    GlanceTextField(
                      controller: _nameController,
                      label: 'Display Name',
                      hint: 'Enter your name',
                      prefixIcon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const Gap(40),

                    // Action Save Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSaveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlanceTheme.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(GlanceTheme.radiusFull),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                'Save Profile',
                                style: GlanceTheme.titleMedium.copyWith(color: Colors.black),
                              ),
                      ),
                    ),
                    const Gap(48),

                    const Divider(color: GlanceTheme.borderSubtle),
                    const Gap(24),

                    // Log out & Delete Buttons
                    OutlinedButton.icon(
                      onPressed: _isSaving ? null : _handleSignOut,
                      icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: GlanceTheme.borderSubtle),
                      ),
                    ),
                    const Gap(16),

                    OutlinedButton.icon(
                      onPressed: _isSaving ? null : _handleDeleteAccount,
                      icon: const Icon(Icons.delete_forever_rounded, color: GlanceTheme.error),
                      label: const Text('Delete Account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GlanceTheme.error,
                        side: const BorderSide(color: GlanceTheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: GlanceTheme.primary)),
        error: (err, _) => Center(child: Text('Error loading profile: $err', style: const TextStyle(color: GlanceTheme.error))),
      ),
    );
  }
}
