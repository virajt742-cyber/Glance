import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import 'package:glance_app/core/theme/glance_theme.dart';
import 'package:glance_app/core/providers/providers.dart';
import 'package:glance_app/features/group/screens/create_group_screen.dart';
import 'package:glance_app/features/profile/screens/profile_settings_screen.dart';

class GroupManagementScreen extends ConsumerStatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  ConsumerState<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends ConsumerState<GroupManagementScreen> {
  final _joinCodeController = TextEditingController();
  bool _isJoining = false;
  bool _isGeneratingInvite = false;
  bool _isModifyingGroup = false;
  String? _generatedInviteCode;

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleLeaveGroup(String groupId, String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GlanceTheme.surfaceElevated,
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group? You will no longer receive or share moments in this group.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: GlanceTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GlanceTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isModifyingGroup = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.removeMemberFromGroup(groupId, userId);

      // Select another group if available, otherwise set active group to null
      final groups = ref.read(userGroupsProvider).value ?? [];
      final remainingGroups = groups.where((g) => g.id != groupId).toList();

      if (remainingGroups.isNotEmpty) {
        ref.read(activeGroupIdProvider.notifier).state = remainingGroups.first.id;
      } else {
        ref.read(activeGroupIdProvider.notifier).state = null;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully left the group.'),
            backgroundColor: GlanceTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave group: $e'),
            backgroundColor: GlanceTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isModifyingGroup = false);
    }
  }

  Future<void> _handleDeleteGroup(String groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GlanceTheme.surfaceElevated,
        title: const Text('Delete Group', style: TextStyle(color: GlanceTheme.error)),
        content: const Text('Are you sure you want to permanently delete this group? All shared moments and invite codes will be deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: GlanceTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GlanceTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isModifyingGroup = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.deleteGroup(groupId);

      // Select another group if available, otherwise set active group to null
      final groups = ref.read(userGroupsProvider).value ?? [];
      final remainingGroups = groups.where((g) => g.id != groupId).toList();

      if (remainingGroups.isNotEmpty) {
        ref.read(activeGroupIdProvider.notifier).state = remainingGroups.first.id;
      } else {
        ref.read(activeGroupIdProvider.notifier).state = null;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group successfully deleted.'),
            backgroundColor: GlanceTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete group: $e'),
            backgroundColor: GlanceTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isModifyingGroup = false);
    }
  }

  Future<void> _handleJoinGroup() async {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isJoining = true);

    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      final firestoreService = ref.read(firestoreServiceProvider);
      final group = await firestoreService.joinGroupWithCode(
        inviteCode: code,
        userId: userId,
      );

      // Set as active group
      ref.read(activeGroupIdProvider.notifier).state = group.id;

      _joinCodeController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined "${group.name}"!'),
            backgroundColor: GlanceTheme.success,
          ),
        );
      }
    // ERROR FIX: Catch TimeoutException during join group and guide user to verify Firestore console setup.
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Join request timed out. Please check your network connection and verify that Cloud Firestore is created and enabled in your Firebase Console.'),
            backgroundColor: GlanceTheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: GlanceTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _handleGenerateInvite(String groupId) async {
    setState(() => _isGeneratingInvite = true);
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      final invite = await firestoreService.createInvite(
        groupId: groupId,
        createdBy: userId,
      );

      setState(() {
        _generatedInviteCode = invite.inviteCode;
      });
    } catch (e) {
      if (mounted) {
        // ERROR FIX: Inform the user to check their Firebase Console database setup when invite code generation times out.
        final isTimeout = e is TimeoutException || e.toString().contains('TimeoutException');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTimeout
                ? 'Failed to generate invite code: Request timed out. Verify that Cloud Firestore is created and enabled in your Firebase Console.'
                : 'Failed to generate invite code: $e'),
            backgroundColor: GlanceTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingInvite = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite code copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeGroup = ref.watch(activeGroupProvider).value;
    final groups = ref.watch(userGroupsProvider).value ?? [];
    final membersAsync = ref.watch(activeGroupMembersProvider);

    return Scaffold(
      backgroundColor: GlanceTheme.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Groups', style: GlanceTheme.displayMedium),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 26),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: GlanceTheme.primary, size: 28),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Gap(24),

              // ─── Group Selector / Active Group Indicator ───
              if (groups.isNotEmpty) ...[
                Text('Active Group', style: GlanceTheme.titleMedium.copyWith(color: GlanceTheme.textSecondary)),
                const Gap(12),
                DropdownButtonFormField<String>(
                  initialValue: activeGroup?.id,
                  dropdownColor: GlanceTheme.surfaceElevated,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    fillColor: GlanceTheme.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(GlanceTheme.radiusMd),
                      borderSide: const BorderSide(color: GlanceTheme.borderSubtle),
                    ),
                  ),
                  items: groups.map((g) {
                    return DropdownMenuItem<String>(
                      value: g.id,
                      child: Text(g.name, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      ref.read(activeGroupIdProvider.notifier).state = id;
                      setState(() {
                        _generatedInviteCode = null; // Clear old generated codes
                      });
                    }
                  },
                ),
                const Gap(24),
              ],

              // ─── Join Group via Code ───
              Text('Join Group', style: GlanceTheme.titleMedium.copyWith(color: GlanceTheme.textSecondary)),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _joinCodeController,
                      style: GlanceTheme.bodyLarge.copyWith(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter 6-digit code',
                        fillColor: GlanceTheme.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(GlanceTheme.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  const Gap(12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isJoining ? null : _handleJoinGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GlanceTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(GlanceTheme.radiusMd),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: _isJoining
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('Join', style: TextStyle(color: Colors.black)),
                    ),
                  ),
                ],
              ),
              const Gap(32),

              // ─── Active Group Members & Invite Details ───
              if (activeGroup != null) ...[
                // Members Title & Count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Members (${activeGroup.memberIds.length})',
                      style: GlanceTheme.titleMedium.copyWith(color: GlanceTheme.textSecondary),
                    ),
                  ],
                ),
                const Gap(12),

                // Members List
                membersAsync.when(
                  data: (members) => Container(
                    decoration: BoxDecoration(
                      color: GlanceTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(GlanceTheme.radiusLg),
                      border: Border.all(color: GlanceTheme.borderSubtle, width: 0.5),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final isCreator = member.id == activeGroup.creatorId;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: GlanceTheme.surfaceElevated,
                            backgroundImage: member.profilePicUrl.isNotEmpty
                                ? NetworkImage(member.profilePicUrl)
                                : null,
                            child: member.profilePicUrl.isEmpty
                                ? Text(
                                    member.displayName.characters.firstOrNull?.toUpperCase() ?? 'U',
                                    style: const TextStyle(color: GlanceTheme.primary),
                                  )
                                : null,
                          ),
                          title: Text(
                            member.displayName,
                            style: GlanceTheme.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            member.email,
                            style: GlanceTheme.bodySmall,
                          ),
                          trailing: isCreator
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: GlanceTheme.primarySurface,
                                    borderRadius: BorderRadius.circular(GlanceTheme.radiusXs),
                                  ),
                                  child: Text(
                                    'Admin',
                                    style: GlanceTheme.labelSmall.copyWith(color: GlanceTheme.primary),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(color: GlanceTheme.primary),
                    ),
                  ),
                  error: (err, _) => Text('Error loading members: $err', style: const TextStyle(color: GlanceTheme.error)),
                ),
                const Gap(32),

                // Invite Code Generation Section
                Text(
                  'Invite Friends',
                  style: GlanceTheme.titleMedium.copyWith(color: GlanceTheme.textSecondary),
                ),
                const Gap(12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: GlanceTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(GlanceTheme.radiusLg),
                    border: Border.all(color: GlanceTheme.borderSubtle, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Generate a 6-character code to invite friends to join this group. Code expires in 48 hours.',
                        style: GlanceTheme.bodyMedium,
                      ),
                      const Gap(20),
                      if (_generatedInviteCode != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: GlanceTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(GlanceTheme.radiusMd),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _generatedInviteCode!,
                                style: GlanceTheme.displayMedium.copyWith(
                                  color: GlanceTheme.primary,
                                  letterSpacing: 8,
                                ),
                              ),
                              const Gap(8),
                              GestureDetector(
                                onTap: () => _copyToClipboard(_generatedInviteCode!),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.copy_rounded, color: GlanceTheme.primary, size: 16),
                                    const Gap(8),
                                    Text(
                                      'Copy Code',
                                      style: GlanceTheme.bodyLarge.copyWith(color: GlanceTheme.primary, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Gap(16),
                      ],
                      ElevatedButton(
                        onPressed: _isGeneratingInvite ? null : () => _handleGenerateInvite(activeGroup.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlanceTheme.surfaceCard,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(GlanceTheme.radiusMd),
                            side: const BorderSide(color: GlanceTheme.borderSubtle, width: 0.5),
                          ),
                        ),
                        child: _isGeneratingInvite
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_generatedInviteCode == null ? 'Generate Code' : 'Generate New Code'),
                      ),
                    ],
                  ),
                ),
                
                // ─── Group Settings (Leave / Delete) ───
                const Gap(32),
                Text(
                  'Group Actions',
                  style: GlanceTheme.titleMedium.copyWith(color: GlanceTheme.textSecondary),
                ),
                const Gap(12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: GlanceTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(GlanceTheme.radiusLg),
                    border: Border.all(color: GlanceTheme.borderSubtle, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (activeGroup.creatorId == ref.read(currentUserIdProvider)) ...[
                        Text(
                          'You are the owner of this group. Deleting the group will remove all members and delete all posts permanently.',
                          style: GlanceTheme.bodyMedium,
                        ),
                        const Gap(20),
                        ElevatedButton.icon(
                          onPressed: _isModifyingGroup ? null : () => _handleDeleteGroup(activeGroup.id),
                          icon: const Icon(Icons.delete_forever_rounded, color: Colors.white),
                          label: _isModifyingGroup
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Delete Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GlanceTheme.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GlanceTheme.radiusMd),
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'You will lose access to all moments shared in this group once you leave.',
                          style: GlanceTheme.bodyMedium,
                        ),
                        const Gap(20),
                        ElevatedButton.icon(
                          onPressed: _isModifyingGroup ? null : () => _handleLeaveGroup(activeGroup.id, ref.read(currentUserIdProvider)!),
                          icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white),
                          label: _isModifyingGroup
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Leave Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GlanceTheme.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GlanceTheme.radiusMd),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                // Empty state if no group is selected / exists
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.group_work_rounded, color: GlanceTheme.textTertiary, size: 64),
                      const Gap(16),
                      Text(
                        'No Group Selected',
                        style: GlanceTheme.headlineMedium,
                      ),
                      const Gap(8),
                      Text(
                        'Create a new group or join using a friend\'s invite code to get started.',
                        style: GlanceTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const Gap(24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                        ),
                        icon: const Icon(Icons.group_add_rounded, color: Colors.black),
                        label: const Text(
                          'Create New Group',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlanceTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(GlanceTheme.radiusFull),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
