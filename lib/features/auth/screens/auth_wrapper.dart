import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glance_app/core/providers/providers.dart';
import 'package:glance_app/features/auth/screens/login_screen.dart';
import 'package:glance_app/features/home/screens/home_screen.dart';
import 'package:glance_app/features/auth/screens/splash_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    debugPrint('[AuthWrapper] Current state: $authState');

    return authState.when(
      data: (user) {
        debugPrint('[AuthWrapper] Data state: user = ${user?.uid}');
        if (user == null) return const LoginScreen();
        return const HomeScreen();
      },
      loading: () {
        debugPrint('[AuthWrapper] Loading state');
        return const SplashScreen();
      },
      error: (err, stack) {
        debugPrint('[AuthWrapper] Error state: $err\n$stack');
        return const LoginScreen();
      },
    );
  }
}
