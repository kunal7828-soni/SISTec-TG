import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  static const String clientId =
      '910068976706-r9g5dec35auvioj1e0frrou1bndpl3u8.apps.googleusercontent.com';

  static const List<String> scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;

  Future<void> initialize() async {
    await _googleSignIn.initialize(
      clientId: clientId,
    );

    _googleSignIn.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _currentUser = event.user;
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          _currentUser = null;
        }
      },
    );

    await _googleSignIn.attemptLightweightAuthentication();
  }

  Future<GoogleSignInAccount> signIn() async {
    final user = await _googleSignIn.authenticate(
      scopeHint: scopes,
    );

    _currentUser = user;

    return user;
  }

  Future<String?> getAccessToken() async {
    final user = _currentUser;

    if (user == null) {
      return null;
    }

    final authorization =
        await user.authorizationClient.authorizationForScopes(scopes);

    return authorization?.accessToken;
  }

  Future<String> authorizeSheets() async {
    final user = _currentUser;

    if (user == null) {
      throw Exception('Please sign in with Google first.');
    }

    final authorization =
        await user.authorizationClient.authorizeScopes(scopes);

    return authorization.accessToken;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }
}
