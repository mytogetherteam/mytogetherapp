import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Result of a Google → Firebase sign-in attempt.
class GoogleSignInResult {
  final String idToken;
  final String? name;
  final String? email;

  const GoogleSignInResult({
    required this.idToken,
    this.name,
    this.email,
  });
}

/// Shared Google Sign-In for Android + iOS via Firebase Auth.
class GoogleAuthHelper {
  GoogleAuthHelper._();

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
  );

  /// Opens the Google account picker, links Firebase, returns a Firebase ID token.
  /// Returns null when the user cancels.
  static Future<GoogleSignInResult?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final googleAuth = await account.authentication;
    if (googleAuth.idToken == null && googleAuth.accessToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-auth-token',
        message: 'Google Sign-In did not return credentials.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final firebaseIdToken = await userCred.user?.getIdToken();
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Failed to get Firebase ID token after Google Sign-In.',
      );
    }

    final user = userCred.user;
    return GoogleSignInResult(
      idToken: firebaseIdToken,
      name: user?.displayName ?? account.displayName,
      email: user?.email ?? account.email,
    );
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}
