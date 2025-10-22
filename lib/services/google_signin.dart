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
      print('🔵 Starting Google authentication...');

      final googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      print('🔵 authenticate() returned: ${googleUser != null ? "SUCCESS" : "NULL"}');

      if (googleUser == null) {
        print("❌ User canceled or authentication failed");
        return null;
      }

      print('🔵 Got Google user: ${googleUser.email}');
      print('🔵 Getting authentication details...');

      final googleAuth = googleUser.authentication;
      print('🔵 ID Token: ${googleAuth.idToken != null ? "EXISTS" : "NULL"}');

      final authClient = googleUser.authorizationClient;
      final authorization = await authClient.authorizationForScopes([]);
      print('🔵 Access Token: ${authorization?.accessToken != null ? "EXISTS" : "NULL"}');

      // ... rest of your code
    } on GoogleSignInException catch (e) {
      print("❌ GoogleSignInException: ${e.code} - ${e.toString()}");
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
