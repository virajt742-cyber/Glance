import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glance_app/core/theme/glance_theme.dart';
import 'package:glance_app/core/providers/providers.dart';
import 'package:glance_app/core/models/models.dart';
import 'package:glance_app/features/camera/screens/camera_screen.dart';
import 'package:glance_app/features/feed/screens/feed_screen.dart';
import 'package:glance_app/features/group/screens/group_management_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final PageController _pageController;
  int _currentPageIndex = 1; // Start in camera view (center)

  @override
  void initState() {
    super.initState();
    _currentPageIndex = ref.read(homePageIndexProvider);
    _pageController = PageController(initialPage: _currentPageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to homePageIndexProvider to animate the PageController when updated externally
    ref.listen<int>(homePageIndexProvider, (previous, next) {
      if (next != _currentPageIndex) {
        _navigateToPage(next);
      }
    });

    // Listen to userGroupsProvider to automatically select the first group when loaded
    ref.listen<AsyncValue<List<GroupModel>>>(userGroupsProvider, (previous, next) {
      next.whenData((groups) {
        if (groups.isNotEmpty && ref.read(activeGroupIdProvider) == null) {
          ref.read(activeGroupIdProvider.notifier).state = groups.first.id;
        }
      });
    });
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Swipeable Horizontal PageView ───
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPageIndex = index;
              });
              ref.read(homePageIndexProvider.notifier).state = index;
            },
            children: const [
              GroupManagementScreen(), // Page 0
              CameraScreen(),            // Page 1 (Center)
              FeedScreen(),              // Page 2
            ],
          ),

          // ─── Top Navigation Icons ───
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: _currentPageIndex == 1, // Let camera page handle its own top controls when active
              child: AnimatedOpacity(
                opacity: _currentPageIndex != 1 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // To Left Page (Groups)
                      IconButton(
                        icon: const Icon(Icons.group_rounded, color: Colors.white),
                        onPressed: () => ref.read(homePageIndexProvider.notifier).state = 0,
                      ),
                      // Center (Go back to Camera)
                      IconButton(
                        icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                        onPressed: () => ref.read(homePageIndexProvider.notifier).state = 1,
                      ),
                      // To Right Page (Feed)
                      IconButton(
                        icon: const Icon(Icons.photo_library_rounded, color: Colors.white),
                        onPressed: () => ref.read(homePageIndexProvider.notifier).state = 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── Bottom Navigation Dots / Touch Bar Indicator ───
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final isSelected = _currentPageIndex == index;
                return GestureDetector(
                  onTap: () => ref.read(homePageIndexProvider.notifier).state = index,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: isSelected ? 12 : 8,
                    height: isSelected ? 12 : 8,
                    decoration: BoxDecoration(
                      color: isSelected ? GlanceTheme.primary : Colors.white54,
                      shape: BoxShape.circle,
                      boxShadow: isSelected ? GlanceTheme.glowPrimary : null,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
