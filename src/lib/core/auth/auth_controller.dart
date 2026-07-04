import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_account.dart';
import 'auth_port.dart';

/// UI-facing auth state: who is signed in, whether an auth op is in flight, and
/// the last error message (cleared on the next successful transition).
class AuthUiState {
  final AuthAccount? account;
  final bool busy;
  final String? error;

  const AuthUiState({this.account, this.busy = false, this.error});

  bool get isSignedIn => account != null;
}

/// Bridges [AuthPort] to Riverpod: mirrors backend auth changes into
/// [AuthUiState] and exposes sign-in / sign-out intents.
class AuthController extends StateNotifier<AuthUiState> {
  final AuthPort _port;
  StreamSubscription<AuthAccount?>? _sub;

  AuthController(this._port)
      : super(AuthUiState(account: _port.currentAccount)) {
    _sub = _port.authChanges().listen((account) {
      state = AuthUiState(account: account);
    });
  }

  Future<void> signInWithGoogle() async {
    state = AuthUiState(account: state.account, busy: true);
    try {
      await _port.signInWithGoogle();
      state = AuthUiState(account: _port.currentAccount);
    } on AuthFailure catch (e) {
      state = AuthUiState(account: state.account, error: e.message);
    } catch (e) {
      state = AuthUiState(account: state.account, error: '로그인에 실패했습니다.');
    }
  }

  Future<void> signOut() async {
    state = AuthUiState(account: state.account, busy: true);
    try {
      await _port.signOut();
      state = const AuthUiState();
    } catch (e) {
      state = AuthUiState(account: state.account, error: '로그아웃에 실패했습니다.');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Must be overridden in main.dart with the platform auth adapter (or
/// [GuestAuthPort] for guest-only builds).
final authPortProvider = Provider<AuthPort>(
  (ref) => throw UnimplementedError('authPortProvider must be overridden'),
);

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthUiState>(
  (ref) => AuthController(ref.watch(authPortProvider)),
);
