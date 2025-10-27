import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A service class to handle Google Sign-In and authentication using Firebase.
class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Signs in the user with Google and returns auth result with isNewUser flag
  ///
  /// Set [forceAccountPicker] to true to always show the account picker
  /// (useful for testing with multiple accounts)
  ///
  /// Returns a Map with 'user' and 'isNewUser' keys
  Future<Map<String, dynamic>?> signInWithGoogle({
    bool forceAccountPicker = false, // ✅ New parameter
  }) async {
    try {
      print('🔵 Starting Google authentication...');

      // ✅ Force sign out first to show account picker (if requested)
      if (forceAccountPicker) {
        await _googleSignIn.signOut();
        print('🔵 Signed out to force account picker');
      }

      // Show Google account picker and sign in
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print("❌ User canceled the sign-in");
        return null;
      }

      print('🔵 Got Google user: ${googleUser.email}');

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🔵 Signing in to Firebase...');

      // Sign in to Firebase with Google credential
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      print('✅ Firebase sign-in successful!');

      // Check if this is a new user
      final bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        print('🆕 New user - creating Firestore profile');

        // Create user profile in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'email': googleUser.email,
          'displayName': googleUser.displayName ?? '',
          'photoUrl': googleUser.photoUrl ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return {
        'user': userCredential.user,
        'isNewUser': isNewUser,
      };

    } on FirebaseAuthException catch (e) {
      print("❌ Firebase Auth Error: ${e.code} - ${e.message}");
      return null;
    } catch (e) {
      print("❌ Sign-in error: $e");
      return null;
    }
  }

  /// Signs out the user from both Google and Firebase
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
      print("✅ User signed out successfully");
    } catch (e) {
      print("❌ Sign-out error: $e");
    }
  }

  /// Disconnects the user's Google account from the app
  /// This will force the account picker to show on next sign-in
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      await FirebaseAuth.instance.signOut();
      print("✅ User disconnected - account picker will show on next sign-in");
    } catch (e) {
      print("❌ Disconnect error: $e");
    }
  }

  /// Check if user is currently signed in to Google
  bool isSignedIn() {
    return _googleSignIn.currentUser != null;
  }

  /// Get the currently signed-in Google user (if any)
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
}
