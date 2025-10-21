import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:myapp/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A service class to handle Google Sign-In
/// and authentication using Firebase.
class GoogleAuthService {
  // Get the singleton instance
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final DatabaseService _dbService = DatabaseService();
  bool _isInitialized = false;

  /// Initialize Google Sign-In before first use
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _googleSignIn.initialize(
        serverClientId: '1008163722435-uk17hk6skq5hu66q025cnf82q8uk8for.apps.googleusercontent.com',
      );
      _isInitialized = true;
    }
  }

  /// Signs in the user with Google and returns auth result with isNewUser flag
  ///
  /// Returns a Map with 'user' and 'isNewUser' keys
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      await _ensureInitialized();

      // Trigger the authentication flow
      final googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      // User canceled the sign-in
      if (googleUser == null) {
        print("Sign-in canceled by user");
        return null;
      }

      // Get authentication details
      final googleAuth = googleUser.authentication;
      final authClient = googleUser.authorizationClient;
      final authorization = await authClient.authorizationForScopes([]);

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: authorization?.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final user = userCredential.user;
      if (user == null) return null;

      // ✅ Check if this is a new user or existing user
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      print("✅ Google Sign-in successful: ${user.email}");
      print("📊 Is new user: $isNewUser");

      // ✅ If existing user, check if profile is complete
      if (!isNewUser) {
        final hasCompleteProfile = await _checkProfileComplete(user.uid);
        if (!hasCompleteProfile) {
          print("⚠️ Existing user but profile incomplete");
          return {'user': user, 'isNewUser': true}; // Treat as new
        }
      }

      return {
        'user': user,
        'isNewUser': isNewUser,
      };

    } on GoogleSignInException catch (e) {
      print("❌ GoogleSignInException: ${e.code}");
      return null;
    } catch (e) {
      print("❌ Sign-in error: $e");
      return null;
    }
  }

  /// Check if user has a complete profile in Firestore
  Future<bool> _checkProfileComplete(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) return false;

      final data = doc.data();
      // Check if required fields exist
      return data?['age'] != null &&
          data?['email'] != null;
    } catch (e) {
      print("Error checking profile: $e");
      return false;
    }
  }

  /// Signs out the user from both Google and Firebase.
  Future<void> signOut() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
    print("✅ User signed out");
  }
}
