import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../homepage.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';
import 'package:myapp/services/google_signin.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Required keys for HomePage
  final GlobalKey stepGaugeKey = GlobalKey();
  final GlobalKey dailyStreakKey = GlobalKey();
  final GlobalKey pointsEarnedKey = GlobalKey();
  final GlobalKey mockStepsKey = GlobalKey();

  bool isLoading = false;

  Future<void> loginUser() async {
    setState(() => isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            stepGaugeKey: stepGaugeKey,
            dailyStreakKey: dailyStreakKey,
            pointsEarnedKey: pointsEarnedKey,
            mockStepsKey: mockStepsKey,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Image.asset('assets/app_logo.png', height: 150)),

            const SizedBox(height: 40),

            Text("Log in", style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),

            const SizedBox(height: 12),
            Text(
              "By logging in, you agree to our Terms of Use.",
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),

            const SizedBox(height: 6),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage()));
                },
                child: const Text("Forgot Password?", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.orange)),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loginUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Connect", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),

            const SizedBox(height: 20),
            Row(children: const [Expanded(child: Divider()), Text("  OR  "), Expanded(child: Divider())]),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () async {
                final result = await GoogleAuthService().signInWithGoogle();
                if (result == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Google Sign-In was cancelled or failed")),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Signed in with Google")),
                  );

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HomePage(
                        stepGaugeKey: stepGaugeKey,
                        dailyStreakKey: dailyStreakKey,
                        pointsEarnedKey: pointsEarnedKey,
                        mockStepsKey: mockStepsKey,
                      ),
                    ),
                  );
                }
              },
              icon: Image.asset('assets/google_icon.png', height: 24),
              label: const Text('Sign in with Google'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: () {}, // TODO: Facebook login functionality
              icon: const Icon(Icons.facebook, color: Colors.blue),
              label: const Text('Sign in with Facebook'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 30),

            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupPage()));
                },
                child: const Text("Don't have an account? Sign up"),
              ),
            ),

            const SizedBox(height: 8),

            Center(
              child: Text(
                "For more info, please see our Privacy Policy.",
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
