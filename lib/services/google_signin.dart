import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// A service class to handle Google Sign-In
/// and authentication using Firebase.
class GoogleAuthService {
  // Get the singleton instance
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
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

  /// Signs in the user with Google and returns the authenticated Firebase [User].
  ///
  /// Returns `null` if the sign-in process is canceled or fails.
  Future<User?> signInWithGoogle() async {
    try {
      // Ensure initialization before use
      await _ensureInitialized();

      // Trigger the authentication flow with scopes
      final googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      // User canceled the sign-in
      if (googleUser == null) {
        print("Sign-in canceled by user");
        return null;
      }

      // Get authentication details (idToken only)
      final googleAuth = googleUser.authentication;

      // Get access token via authorization client
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

      print("✅ Sign-in successful: ${userCredential.user?.email}");
      return userCredential.user;

    } on GoogleSignInException catch (e) {
      print("❌ GoogleSignInException: ${e.code} - ${e.toString()}");
      return null;
    } catch (e) {
      print("❌ Sign-in error: $e");
      return null;
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
