import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/auth/auth_account.dart';
import 'package:time_tracker/core/auth/auth_controller.dart';
import 'package:time_tracker/core/auth/auth_port.dart';

/// In-memory [AuthPort]: drives every state transition without any live
/// Google/Supabase network call.
class _FakeAuthPort implements AuthPort {
  AuthAccount? _account;
  final _controller = StreamController<AuthAccount?>.broadcast();

  /// When set, [signInWithGoogle] throws it instead of signing in.
  AuthFailure? failWith;

  /// When true, [signInWithGoogle] simulates a user cancel (returns null).
  bool cancel = false;

  _FakeAuthPort({AuthAccount? initial}) : _account = initial;

  static const _sample = AuthAccount(
    id: 'user-1',
    email: 'a@b.com',
    displayName: '테스터',
  );

  @override
  AuthAccount? get currentAccount => _account;

  @override
  Stream<AuthAccount?> authChanges() => _controller.stream;

  @override
  Future<AuthAccount?> signInWithGoogle() async {
    if (failWith != null) throw failWith!;
    if (cancel) return null;
    _account = _sample;
    _controller.add(_account);
    return _account;
  }

  @override
  Future<void> signOut() async {
    _account = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}

void main() {
  late _FakeAuthPort port;

  setUp(() => port = _FakeAuthPort());
  tearDown(() => port.dispose());

  test('starts as guest when no account', () {
    final controller = AuthController(port);
    expect(controller.state.isSignedIn, isFalse);
    expect(controller.state.account, isNull);
    controller.dispose();
  });

  test('starts signed-in when the port already has an account', () {
    port = _FakeAuthPort(initial: _FakeAuthPort._sample);
    final controller = AuthController(port);
    expect(controller.state.isSignedIn, isTrue);
    expect(controller.state.account?.email, 'a@b.com');
    controller.dispose();
  });

  test('guest -> signInWithGoogle -> signed-in', () async {
    final controller = AuthController(port);

    await controller.signInWithGoogle();

    expect(controller.state.isSignedIn, isTrue);
    expect(controller.state.account?.label, '테스터');
    expect(controller.state.busy, isFalse);
    expect(controller.state.error, isNull);
    controller.dispose();
  });

  test('signed-in -> signOut -> guest, error stays null', () async {
    final controller = AuthController(port);
    await controller.signInWithGoogle();

    await controller.signOut();

    expect(controller.state.isSignedIn, isFalse);
    expect(controller.state.account, isNull);
    expect(controller.state.busy, isFalse);
    expect(controller.state.error, isNull);
    controller.dispose();
  });

  test('sign-in failure surfaces error and stays guest', () async {
    port.failWith = const AuthFailure('Google 로그인 실패');
    final controller = AuthController(port);

    await controller.signInWithGoogle();

    expect(controller.state.isSignedIn, isFalse);
    expect(controller.state.error, 'Google 로그인 실패');
    expect(controller.state.busy, isFalse);
    controller.dispose();
  });

  test('user cancel leaves guest state with no error', () async {
    port.cancel = true;
    final controller = AuthController(port);

    await controller.signInWithGoogle();

    expect(controller.state.isSignedIn, isFalse);
    expect(controller.state.error, isNull);
    expect(controller.state.busy, isFalse);
    controller.dispose();
  });

  test('external sign-in (stream) updates state', () async {
    final controller = AuthController(port);

    port._account = _FakeAuthPort._sample;
    port._controller.add(_FakeAuthPort._sample);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.isSignedIn, isTrue);
    controller.dispose();
  });
}
