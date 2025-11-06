import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State createState() => _VerificationPageState();
}

class _VerificationPageState extends State {
  late Timer _timer;
  bool _isEmailVerified = false;
  bool _showRedirecting = false;
  int _checkAttempts = 0;
  static const int _maxAttempts = 30;

  @override
  void initState() {
    super.initState();
    debugPrint('📧 VerificationPage: Initialized');

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkEmailVerified();
    });

    _checkEmailVerified();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    if (!mounted) return;

    _checkAttempts++;

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Reload to get latest status from Firebase
      await user.reload();
      user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        debugPrint('✅ VerificationPage: Email verified!');

        if (!_isEmailVerified && mounted) {
          _isEmailVerified = true;
          _timer.cancel();

          setState(() {
            _showRedirecting = true;
          });

          await Future.delayed(const Duration(milliseconds: 800));

          if (mounted) {
            debugPrint('🔄 VerificationPage: Popping self and letting parent rebuild');
            // 🟢 FIX: Use pushReplacementNamed instead of pop
            // This ensures the parent AuthGate rebuilds with fresh user data
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        }
      } else {
        if (_checkAttempts % 5 == 0) {
          debugPrint('⏳ Email not verified. Attempt: $_checkAttempts/$_maxAttempts');
        }

        if (_checkAttempts >= _maxAttempts) {
          _timer.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Verification taking too long. Try again later.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Verification check error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mail_outline,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),

              Text(
                'Verify Your Email',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'We sent a link to:\n${FirebaseAuth.instance.currentUser?.email}',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              if (_showRedirecting)
                Column(
                  children: [
                    Icon(Icons.check_circle, size: 60, color: Colors.green),
                    const SizedBox(height: 16),
                    Text(
                      'Email Verified! Redirecting...',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Checking verification...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),

              const SizedBox(height: 40),

              if (!_showRedirecting)
                Column(
                  children: [
                    Text(
                      'Check your inbox and spam folder',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: _resendEmail,
                      icon: const Icon(Icons.email),
                      label: const Text('Resend Email'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        _timer.cancel();
                        await FirebaseAuth.instance.signOut();
                      },
                      child: const Text('Log Out'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resendEmail() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Email sent!')),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }
}
