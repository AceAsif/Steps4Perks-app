import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:steps4perks/services/database_service.dart';
// 🟢 REMOVED: This page no longer navigates
// import 'package:steps4perks/features/bottomnavigation.dart';

class ProfileCompletionPage extends StatefulWidget {
  // 🟢 REMOVED: 'user' parameter is no longer passed in
  const ProfileCompletionPage({super.key});

  @override
  State<ProfileCompletionPage> createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;

  // 🟢 ADDED: We get the user from FirebaseAuth
  User? _user;

  @override
  void initState() {
    super.initState();
    // 🟢 CHANGED: Get the user from FirebaseAuth first
    _user = FirebaseAuth.instance.currentUser;

    if (_user == null) {
      // This should not happen if AuthGate is working, but it's a safe fallback.
      debugPrint("❌ FATAL: ProfileCompletionPage loaded with no user.");
      // Navigate to login if something went wrong
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } else {
      // Now that we have the user, pre-fill the name
      _nameController.text = _user!.displayName ?? '';
    }

    // 🟢 REMOVED: _loadExistingProfile() is not needed
    // AuthGate already confirmed the profile doesn't exist.
    // We just need to pre-fill the name from the auth provider (like Google).
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // 🟢 Add a null check for the user
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User session not found. Please log in again.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final age = int.parse(_ageController.text.trim());
      final name = _nameController.text.trim();

      // 🟢 CHANGED: Create Firestore user document using _user
      await _dbService.createUserDocument(
        userUid: _user!.uid,
        email: _user!.email ?? '',
        age: age,
      );

      // Update display name in both Firebase Auth and Firestore
      if (name.isNotEmpty && name != _user!.displayName) {
        await _user!.updateDisplayName(name);
        await _dbService.updateUserName(name);
      }

      print('✅ Profile completed for ${_user!.email}');

      // 🟢 REMOVED: The Navigator.pushReplacement() call
      // The StreamBuilder in AuthGate will now detect
      // that the user document exists and will automatically
      // navigate to the OnboardingPage.

      // We just pop the loading dialog if it's there,
      // but since we just set state, the AuthGate will
      // rebuild and handle the rest.

    } catch (e) {
      print('❌ Error completing profile: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              Text(
                'Welcome!',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please complete your profile to continue',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),

              // Email (read-only)
              TextFormField(
                // 🟢 CHANGED: Get email from _user
                initialValue: _user?.email ?? 'Loading...',
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),

              // Name field (editable)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person),
                  hintText: 'Enter your full name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Age field
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  prefixIcon: Icon(Icons.cake),
                  hintText: 'Must be 18 or older',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your age';
                  }
                  final age = int.tryParse(value);
                  if (age == null || age < 18 || age > 120) {
                    return 'You must be at least 18 years old';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _completeProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Info text
              Center(
                child: Text(
                  'We need this information to personalize your experience',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}