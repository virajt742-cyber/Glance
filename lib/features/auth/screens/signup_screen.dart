import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glance_app/core/theme/glance_theme.dart';
import 'package:glance_app/core/providers/providers.dart';
import 'package:glance_app/features/auth/widgets/glance_text_field.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
    bool _isLoading = false;
    bool _obscurePassword = true;
    bool _acceptedEula = false;

    @override
    void dispose() {
      _displayNameController.dispose();
      _emailController.dispose();
      _passwordController.dispose();
      super.dispose();
    }

    void _showEulaDialog() {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('EULA & Terms of Service'),
            content: const SingleChildScrollView(
              child: Text(
                'By using Glance, you agree to our Terms and End User License Agreement:\n\n'
                '1. Zero Tolerance for Abusive Content: You must not upload, share, or transmit any user generated content (UGC) that is abusive, harassing, threatening, hateful, discriminatory, sexually explicit, or otherwise objectionable.\n\n'
                '2. Moderation and Enforcement: We reserve the right to moderate, delete, or filter any content that violates these terms. We also reserve the right to immediately suspend or ban users who post such content.\n\n'
                '3. User Reporting and Blocking: Any user can flag/report offensive content and block abusive users. Flagged content is reviewed within 24 hours, and appropriate moderation action will be taken.\n\n'
                '4. Privacy: We respect your privacy. Photos shared are only shared with members of the specific group you send them to.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close', style: TextStyle(color: GlanceTheme.primary)),
              ),
            ],
          );
        },
      );
    }

    Future<void> _handleSignup() async {
      if (!_formKey.currentState!.validate()) return;

      if (!_acceptedEula) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must accept the EULA & Terms of Service to sign up.'),
            backgroundColor: GlanceTheme.error,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _displayNameController.text,
      );
      if (mounted) {
        // Go back to wrapper which will switch to HomeScreen
        Navigator.of(context).popUntil((route) => route.isFirst);
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
      if (mounted) setState(() => _isLoading = false);
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: GlanceTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Create account',
                  style: GlanceTheme.displayMedium,
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 8),
                Text(
                  'Start sharing daily moments with friends',
                  style: GlanceTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
                const SizedBox(height: 40),

                // Name field
                GlanceTextField(
                  controller: _displayNameController,
                  label: 'Name',
                  hint: 'Your display name',
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
                ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),
                const SizedBox(height: 16),

                // Email field
                GlanceTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
                const SizedBox(height: 16),

                // Password field
                GlanceTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: GlanceTheme.textTertiary,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1),
                const SizedBox(height: 16),

                // EULA / ToS Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _acceptedEula,
                      onChanged: (val) {
                        setState(() {
                          _acceptedEula = val ?? false;
                        });
                      },
                      activeColor: GlanceTheme.primary,
                      checkColor: Colors.black,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showEulaDialog,
                        child: Text.rich(
                          TextSpan(
                            text: 'I agree to the ',
                            style: GlanceTheme.bodyMedium,
                            children: [
                              TextSpan(
                                text: 'EULA & Terms of Service',
                                style: GlanceTheme.bodyMedium.copyWith(
                                  color: GlanceTheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 550.ms),
                const SizedBox(height: 24),

                // Register button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlanceTheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(GlanceTheme.radiusFull),
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
                            'Sign Up',
                            style: GlanceTheme.titleMedium
                                .copyWith(color: Colors.black),
                          ),
                  ),
                ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
                const SizedBox(height: 24),

                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: GlanceTheme.bodyMedium,
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        'Sign In',
                        style: GlanceTheme.titleMedium.copyWith(
                          color: GlanceTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 700.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
