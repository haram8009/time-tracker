import 'auth_account.dart';

/// Raised when a sign-in / sign-out attempt fails for a reason worth showing
/// to the user. Cancellation is NOT a failure — it surfaces as a null result.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => 'AuthFailure: $message';
}

/// Abstraction over the auth backend (Supabase + Google). Keeps the controller
/// and UI testable with a fake, so state transitions can be verified without
/// any live Google/Supabase network calls.
abstract interface class AuthPort {
  /// The currently signed-in account, or null for guest.
  AuthAccount? get currentAccount;

  /// Emits the new account (or null on sign-out) whenever auth state changes.
  Stream<AuthAccount?> authChanges();

  /// Runs native Google sign-in and establishes a Supabase session.
  /// Returns the account on success, or null if the user cancelled.
  /// Throws [AuthFailure] on error.
  Future<AuthAccount?> signInWithGoogle();

  /// Clears the Supabase session. Local SQLite data is left untouched.
  Future<void> signOut();
}

/// Auth backend for guest-only builds (Supabase not configured). Always signed
/// out; local SQLite usage is fully available and sign-in reports why it is off.
class GuestAuthPort implements AuthPort {
  const GuestAuthPort();

  @override
  AuthAccount? get currentAccount => null;

  @override
  Stream<AuthAccount?> authChanges() => const Stream.empty();

  @override
  Future<AuthAccount?> signInWithGoogle() async {
    throw const AuthFailure('클라우드 로그인이 이 빌드에 구성되지 않았습니다.');
  }

  @override
  Future<void> signOut() async {}
}
