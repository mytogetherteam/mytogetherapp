import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Result of a Google → Firebase sign-in attempt.
class GoogleSignInResult {
  final String idToken;
  final String? name;
  final String? email;

  /// Google access token, only when registration asked for a profile phone
  /// and the user granted that permission.
  final String? accessToken;

  const GoogleSignInResult({
    required this.idToken,
    this.name,
    this.email,
    this.accessToken,
  });
}

/// Shared Google Sign-In for Android + iOS via Firebase Auth.
class GoogleAuthHelper {
  GoogleAuthHelper._();

  static const _baseScopes = ['email', 'profile'];
  static const _phoneScope =
      'https://www.googleapis.com/auth/user.phonenumbers.read';

  static GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _baseScopes);

  /// Opens the Google account picker, links Firebase, returns a Firebase ID token.
  /// Returns null when the user cancels.
  ///
  /// [requestPhone] includes the profile-phone scope in the sign-in itself.
  /// Android only puts scopes from this list on the access token, so asking
  /// afterwards would not let the server read a number. If that scope is
  /// rejected, sign-in is tried again without it.
  static Future<GoogleSignInResult?> signIn({bool requestPhone = false}) async {
    if (!requestPhone) return _performSignIn(includePhone: false);
    try {
      return await _performSignIn(includePhone: true);
    } catch (_) {
      await signOut();
      return _performSignIn(includePhone: false);
    }
  }

  static Future<GoogleSignInResult?> _performSignIn({
    required bool includePhone,
  }) async {
    _googleSignIn = GoogleSignIn(
      scopes: [
        ..._baseScopes,
        if (includePhone) _phoneScope,
      ],
    );
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
      accessToken: includePhone ? googleAuth.accessToken : null,
    );
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
