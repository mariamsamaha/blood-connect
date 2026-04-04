import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';

import '../routing/app_router.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get onAuthStateChanged => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Disconnect any previous sessions to prevent DUPLICATE_RAW_ID
      try {
        await _googleSignIn.disconnect();
      } on PlatformException {
        // Ignore if there is no active session to disconnect.
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        throw Exception('Failed to obtain authentication tokens from Google');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on PlatformException catch (e) {
      String errorMessage = 'Google Sign-In platform error';
      switch (e.code) {
        case 'network_error':
          errorMessage =
              'Network connection error. Please check your internet connection.';
          break;
        case 'sign_in_failed':
          errorMessage = 'Google Sign-In failed. Please try again.';
          break;
        case 'sign_in_canceled':
          return null;
        default:
          errorMessage =
              'Google Sign-In error: ${e.message ?? 'Unknown error'}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    clearProfileCache();
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
    } on PlatformException {
      // Ignore status errors when GoogleSignIn has no active session.
    }
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
