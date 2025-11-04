import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// A service class to handle Google Sign-In and authentication using Firebase.
///
/// This service manages the complete authentication flow including:
/// - Sign in with Google
/// - Sign out (clearing both Google and Firebase sessions)
/// - Disconnect (force account picker on next login)
class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Signs in the user with Google and returns auth result with isNewUser flag
  ///
  /// Set [forceAccountPicker] to true to always show the account picker
  /// (useful for testing with multiple accounts or switching between users)
  ///
  /// Returns a Map with 'user' and 'isNewUser' keys, or null if sign-in fails
  Future<Map<String, dynamic>?> signInWithGoogle({
    bool forceAccountPicker = false,
  }) async {
    try {
      debugPrint('🔵 Starting Google authentication...');

      // Force account picker if requested (useful for testing multiple accounts)
      if (forceAccountPicker) {
        await _googleSignIn.signOut();
        debugPrint('🔵 Signed out to force account picker');
      }

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // User canceled the sign-in
      if (googleUser == null) {
        debugPrint("⚠️ User canceled the sign-in");
        return null;
      }

      debugPrint('🔵 Got Google user: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('🔵 Signing in to Firebase...');

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      debugPrint('✅ Firebase sign-in successful!');

      // Check if this is a new user
      final bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      // Return user info and new user status
      // AuthGate (in main.dart) will handle routing based on Firestore document existence
      return {
        'user': userCredential.user,
        'isNewUser': isNewUser,
      };
    } on FirebaseAuthException catch (e) {
      debugPrint("❌ Firebase Auth Error: ${e.code} - ${e.message}");
      return null;
    } catch (e, stackTrace) {
      debugPrint("❌ Sign-in error: $e");
      debugPrint("Stack trace: $stackTrace");
      return null;
    }
  }

  /// 🟢 FIXED: Signs out the user from both Google and Firebase
  ///
  /// IMPORTANT: Signs out from Google FIRST to clear authentication cache,
  /// then signs out from Firebase. This prevents issues with re-login attempts.
  Future<void> signOut() async {
    try {
      debugPrint('🔴 Starting sign-out process...');

      // 🟢 CRITICAL FIX: Sign out from Google FIRST
      // This clears Google's authentication cache and prevents stale credential issues
      await _googleSignIn.signOut();
      debugPrint('✅ Signed out from Google');

      // Then sign out from Firebase
      await _auth.signOut();
      debugPrint('✅ Signed out from Firebase');

      debugPrint('✅ Complete sign-out successful!');
    } catch (e, stackTrace) {
      debugPrint('❌ Sign-out error: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - we want sign-out to always succeed even if there's an error
    }
  }

  /// Disconnects the user's Google account from the app completely
  ///
  /// This is more aggressive than signOut() - it removes the app's access
  /// to the Google account entirely. The account picker will always show
  /// on the next sign-in attempt.
  ///
  /// Use this for "Remove Account" functionality or when you want to
  /// force the user to completely re-authenticate.
  Future<void> disconnect() async {
    try {
      debugPrint('🔴 Disconnecting Google account...');

      // Disconnect from Google (removes app access)
      await _googleSignIn.disconnect();
      debugPrint('✅ Disconnected from Google');

      // Sign out from Firebase
      await _auth.signOut();
      debugPrint('✅ Signed out from Firebase');

      debugPrint('✅ Account disconnected - account picker will show on next sign-in');
    } catch (e, stackTrace) {
      debugPrint('❌ Disconnect error: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - we want disconnect to always succeed
    }
  }

  /// Check if user is currently signed in to Google
  ///
  /// Returns true if the user has an active Google Sign-In session
  bool isSignedInToGoogle() {
    return _googleSignIn.currentUser != null;
  }

  /// Check if user is currently signed in to Firebase
  ///
  /// Returns true if the user has an active Firebase session
  bool isSignedInToFirebase() {
    return _auth.currentUser != null;
  }

  /// Get the currently signed-in Google user (if any)
  GoogleSignInAccount? get currentGoogleUser => _googleSignIn.currentUser;

  /// Get the currently signed-in Firebase user (if any)
  User? get currentFirebaseUser => _auth.currentUser;

  /// Get the current user's email (from Firebase)
  String? get currentUserEmail => _auth.currentUser?.email;

  /// Get the current user's UID (from Firebase)
  String? get currentUserUid => _auth.currentUser?.uid;

  /// Get the current user's display name (from Firebase)
  String? get currentUserDisplayName => _auth.currentUser?.displayName;

  /// Get the current user's photo URL (from Firebase)
  String? get currentUserPhotoUrl => _auth.currentUser?.photoURL;
}
