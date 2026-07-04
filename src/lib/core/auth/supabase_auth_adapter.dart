// ignore_for_file: prefer_initializing_formals
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_account.dart';
import 'auth_port.dart';

/// Real [AuthPort]: native Google sign-in (google_sign_in v7) exchanged for a
/// Supabase session via `signInWithIdToken`. Not unit-tested — it performs live
/// network calls; the controller is tested against a fake instead.
class SupabaseAuthAdapter implements AuthPort {
  final SupabaseClient _supabase;
  final GoogleSignIn _googleSignIn;

  SupabaseAuthAdapter({
    required SupabaseClient supabase,
    GoogleSignIn? googleSignIn,
  })  : _supabase = supabase,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  @override
  AuthAccount? get currentAccount => _map(_supabase.auth.currentUser);

  @override
  Stream<AuthAccount?> authChanges() =>
      _supabase.auth.onAuthStateChange.map((e) => _map(e.session?.user));

  @override
  Future<AuthAccount?> signInWithGoogle() async {
    if (!_googleSignIn.supportsAuthenticate()) {
      throw const AuthFailure('이 플랫폼에서는 Google 로그인을 지원하지 않습니다.');
    }

    final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthFailure('Google 로그인 실패: ${e.description ?? e.code.name}');
    }

    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw const AuthFailure('Google ID 토큰을 가져오지 못했습니다.');
    }

    // Supabase needs the OAuth access token alongside the ID token for Google.
    final authz = await googleUser.authorizationClient
        .authorizeScopes(const ['email', 'profile']);

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authz.accessToken,
    );
    return currentAccount;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _supabase.auth.signOut();
  }

  AuthAccount? _map(User? user) {
    if (user == null) return null;
    final meta = user.userMetadata;
    return AuthAccount(
      id: user.id,
      email: user.email,
      displayName:
          meta?['full_name'] as String? ?? meta?['name'] as String?,
    );
  }
}
