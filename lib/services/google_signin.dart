import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      print('🔵 Starting Google authentication...');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print("❌ User canceled the sign-in");
        return null;
      }

      print('🔵 Got Google user: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🔵 Signing in to Firebase...');

      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      print('✅ Firebase sign-in successful!');

      final bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser) {
        print('🆕 New user - creating Firestore profile');

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

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
      print("✅ User signed out successfully");
    } catch (e) {
      print("❌ Sign-out error: $e");
    }
  }
}
