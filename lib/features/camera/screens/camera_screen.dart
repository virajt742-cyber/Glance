import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart'
    if (dart.library.html) 'package:glance_app/core/utils/permission_handler_stub.dart';

import 'package:glance_app/core/theme/glance_theme.dart';
import 'package:glance_app/core/providers/providers.dart';
import 'package:glance_app/features/camera/screens/photo_preview_screen.dart';
import 'package:glance_app/features/group/screens/create_group_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isInitializing = false;
  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionsAndInitCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _isCameraInitialized = false;
      _cameraController = null;
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_selectedCameraIndex);
    }
  }

  Future<void> _requestPermissionsAndInitCamera() async {
    if (kIsWeb) {
      // On web, the browser handles camera permissions natively
      try {
        _cameras = await availableCameras();
      } catch (e) {
        debugPrint('Error getting available cameras on web: $e');
        _cameras = [];
      }

      if (_cameras.isEmpty) {
        // If empty, create a dummy CameraDescription to force CameraController initialization
        // which will trigger the browser permission popup. Use name: '' to avoid OverconstrainedError.
        _cameras = [
          const CameraDescription(
            name: '',
            lensDirection: CameraLensDirection.front,
            sensorOrientation: 0,
          )
        ];
      }

      try {
        await _initCamera(0);
      } catch (e) {
        debugPrint('Error initializing camera on web: $e');
      }
      return;
    }

    final cameraStatus = await Permission.camera.request();
    final microphoneStatus = await Permission.microphone.request();

    if (cameraStatus.isGranted && microphoneStatus.isGranted) {
      try {
        _cameras = await availableCameras();
        if (_cameras.isNotEmpty) {
          await _initCamera(0);
        }
      } catch (e) {
        debugPrint('Error getting available cameras: $e');
      }
    } else {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _initCamera(int cameraIndex) async {
    if (_isInitializing) return;
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _isCameraInitialized = false;
    });

    _cameraController?.dispose();

    final imageFormat = kIsWeb
        ? ImageFormatGroup.jpeg
        : (defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420);

    final controller = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: imageFormat,
    );

    try {
      await controller.initialize();
      
      // If we successfully initialized, get the actual cameras list on Web
      if (kIsWeb) {
        try {
          final realCameras = await availableCameras();
          if (realCameras.isNotEmpty) {
            _cameras = realCameras;
          }
        } catch (e) {
          debugPrint('Error refreshing cameras list: $e');
        }
      }

      // Flash mode is often unsupported on web/laptops and front cameras, catch separately.
      // We skip setting flash mode entirely on Web during initialization to prevent errors.
      if (!kIsWeb) {
        try {
          await controller.setFlashMode(_flashMode);
        } catch (flashError) {
          debugPrint('Flash mode not supported or error: $flashError');
        }
      }

      _cameraController = controller;
      _selectedCameraIndex = cameraIndex;
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e, stack) {
      debugPrint('Camera init error: $e\n$stack');
      if (kIsWeb && mounted) {
        setState(() {
          _cameras = [];
          _isCameraInitialized = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initCamera(nextIndex);
  }

  Future<void> _toggleFlash() async {
    if (kIsWeb) return; // Flash is not supported on Web
    if (_cameraController == null || !_isCameraInitialized) return;

    FlashMode nextFlash;
    switch (_flashMode) {
      case FlashMode.off:
        nextFlash = FlashMode.always;
        break;
      case FlashMode.always:
        nextFlash = FlashMode.torch;
        break;
      case FlashMode.torch:
        nextFlash = FlashMode.off;
        break;
      default:
        nextFlash = FlashMode.off;
    }

    try {
      await _cameraController!.setFlashMode(nextFlash);
      setState(() {
        _flashMode = nextFlash;
      });
    } catch (e) {
      debugPrint('Error setting flash mode: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_isCameraInitialized || _cameraController!.value.isTakingPicture) {
      return;
    }

    try {
      final picture = await _cameraController!.takePicture();
      if (mounted) {
        _navigateToPreview(picture);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take photo: $e'), backgroundColor: GlanceTheme.error),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (pickedFile != null && mounted) {
        _navigateToPreview(pickedFile);
      }
    } catch (e) {
      debugPrint('Error picking from gallery: $e');
    }
  }

  void _navigateToPreview(XFile imageFile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoPreviewScreen(imageFile: imageFile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeGroup = ref.watch(activeGroupProvider).value;
    final groupsAsync = ref.watch(userGroupsProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Camera Preview ───
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: Builder(
                    builder: (context) {
                      // ERROR FIX: Replaced manual Transform.scale math which scaled a stretched layout.
                      // Here, we lock the SizedBox to the exact aspect ratio of the camera feed (displayRatio),
                      // preventing any vertical or horizontal stretching of the camera preview.
                      // Then, FittedBox(fit: BoxFit.cover) handles uniform fullscreen scaling and cropping.
                      final cameraRatio = _cameraController!.value.aspectRatio;
                      final displayRatio = cameraRatio > 1 ? 1 / cameraRatio : cameraRatio;
                      return SizedBox(
                        width: size.width,
                        height: size.width / displayRatio,
                        child: CameraPreview(_cameraController!),
                      );
                    },
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: _isInitializing
                      ? const CircularProgressIndicator(color: GlanceTheme.primary)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              color: GlanceTheme.textSecondary,
                              size: 64,
                            ),
                            const Gap(16),
                            Text(
                              'Camera Access Required',
                              style: GlanceTheme.headlineMedium,
                            ),
                            const Gap(8),
                            Text(
                              'Allow camera permission or use gallery.',
                              style: GlanceTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const Gap(24),
                            ElevatedButton.icon(
                              onPressed: _requestPermissionsAndInitCamera,
                              icon: const Icon(Icons.settings),
                              label: const Text('Grant Permissions'),
                            ),
                          ],
                        ),
                ),
              ),
            ),

          // ─── Camera Overlay Controls ───
          SafeArea(
            child: Column(
              children: [
                // Top Action Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Groups Page Button
                      IconButton(
                        icon: const Icon(
                          Icons.group_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          ref.read(homePageIndexProvider.notifier).state = 0;
                        },
                      ),
                      // Group Selector Indicator (Interactive)
                      GestureDetector(
                        onTap: () {
                          ref.read(homePageIndexProvider.notifier).state = 0;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24, width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.group_work_rounded, color: GlanceTheme.primary, size: 16),
                              const Gap(8),
                              Text(
                                activeGroup?.name ?? 'Select Group',
                                style: GlanceTheme.labelLarge.copyWith(color: Colors.white),
                              ),
                              const Gap(4),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 16),
                            ],
                          ),
                        ),
                      ),
                      // Switch Camera & Flash Buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!kIsWeb)
                            IconButton(
                              icon: Icon(
                                _flashMode == FlashMode.off
                                    ? Icons.flash_off_rounded
                                    : _flashMode == FlashMode.always
                                        ? Icons.flash_on_rounded
                                        : Icons.flash_auto_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: _toggleFlash,
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.flip_camera_ios_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: _toggleCamera,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom Action Bar
                Padding(
                  padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery Button
                      GestureDetector(
                        onTap: _pickFromGallery,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30, width: 1),
                          ),
                          child: const Icon(
                            Icons.photo_library_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),

                      // Capture Button
                      GestureDetector(
                        onTap: _capturePhoto,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 6),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ).animate().scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1.0, 1.0),
                            curve: Curves.easeOutBack,
                            duration: 150.ms,
                          ),

                      // Feed Button
                      GestureDetector(
                        onTap: () {
                          ref.read(homePageIndexProvider.notifier).state = 2;
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30, width: 1),
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Welcome Overlay for No Groups ───
          groupsAsync.when(
            data: (groups) {
              if (groups.isEmpty) {
                return Positioned.fill(
                  child: Container(
                    color: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: GlanceTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(GlanceTheme.radiusLg),
                          border: Border.all(color: GlanceTheme.borderSubtle, width: 0.5),
                          boxShadow: [
                            BoxShadow(
                              color: GlanceTheme.primary.withOpacity(0.1),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: GlanceTheme.primarySurface,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.group_add_rounded,
                                color: GlanceTheme.primary,
                                size: 40,
                              ),
                            ),
                            const Gap(20),
                            Text(
                              'Welcome to Glance!',
                              style: GlanceTheme.displayMedium.copyWith(fontSize: 24),
                              textAlign: TextAlign.center,
                            ),
                            const Gap(10),
                            Text(
                              'Glance is a widget-first app for sharing moments with your closest circle. Create a group or join one with a friend\'s code to get started!',
                              style: GlanceTheme.bodyMedium.copyWith(color: GlanceTheme.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const Gap(24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      ref.read(homePageIndexProvider.notifier).state = 0;
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: GlanceTheme.borderSubtle),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(GlanceTheme.radiusFull),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text('Join Group'),
                                  ),
                                ),
                                const Gap(12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: GlanceTheme.primary,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(GlanceTheme.radiusFull),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text(
                                      'Create Group',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
