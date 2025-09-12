import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// A service class to handle Google Sign-In
// and authentication using Firebase.
class GoogleAuthService {
  // A singleton instance of GoogleSignIn is accessed directly.
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  /// Signs in the user with Google and returns the authenticated Firebase [User].
  ///
  /// Returns `null` if the sign-in process is canceled or fails.
  Future<User?> signInWithGoogle() async {
    try {
      // The new `authenticate()` method triggers the sign-in flow.
      final googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email'],
      );

      // User canceled the sign-in.
      if (googleUser == null) return null;

      // Retrieve the authentication details from the Google account.
      // In version 7.0, this is now a synchronous getter.
      final googleAuth = googleUser.authentication;

      // Create a new credential using the Google authentication details.
      final credential = GoogleAuthProvider.credential(
        //accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential.
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // Return the authenticated user.
      return userCredential.user;
    } catch (e) {
      // Print the error and return null if an exception occurs.
      print("Sign-in error: $e");
      return null;
    }
  }

  /// Signs out the user from both Google and Firebase.
  Future<void> signOut() async {
    // Sign out from Google.
    await _googleSignIn.signOut();

    // Sign out from Firebase.
    await FirebaseAuth.instance.signOut();
  }
}