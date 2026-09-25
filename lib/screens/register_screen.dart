import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:go_router/go_router.dart';
import 'package:opem/core/router.dart';
import 'package:opem/provider/user_provider.dart';
import 'package:opem/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Seamlessly handle OAuth / deep-link redirects back to the app
    _authSub = authService.authStateChanges.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        EasyLoading.dismiss();
        await context.read<UserProvider>().loadProfile();
        if (mounted) {
          context.go(Routes.home);
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    EasyLoading.show(status: 'Creating account…');
    try {
      await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );
      if (!mounted) return;
      await context.read<UserProvider>().loadProfile();
      if (!mounted) return;
      context.go(Routes.home);
    } on AuthException catch (e) {
      EasyLoading.showError(e.message);
    } catch (e) {
      EasyLoading.showError('Error: ${e.toString()}');
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<void> _handleGoogleSignUp() async {
    EasyLoading.show(status: 'Connecting to Google…');
    try {
      final res = await authService.signInWithGoogle();
      if (!mounted) return;
      if (res != null || authService.isSignedIn) {
        EasyLoading.dismiss();
        await context.read<UserProvider>().loadProfile();
        if (!mounted) return;
        context.go(Routes.home);
      } else {
        // Fallback to browser OAuth was initiated: display connecting status while waiting for callback
        EasyLoading.show(status: 'Completing Google Sign-In…');
      }
    } on AuthException catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError(e.message);
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('Google sign up failed: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleSignUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Register', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => context.push(Routes.phoneLogin),
                icon: const Icon(Icons.phone_iphone_rounded, size: 22, color: Color(0xFF059669)),
                label: const Text('Sign up with Phone Number', style: TextStyle(fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _handleGoogleSignUp,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Sign up with Google', style: TextStyle(fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
