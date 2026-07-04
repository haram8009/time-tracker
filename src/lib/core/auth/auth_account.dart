/// A signed-in user identity, mapped from the Supabase session.
///
/// Guest usage is represented by the absence of an [AuthAccount] (null), not by
/// a special instance — logged-out users never carry an id.
class AuthAccount {
  /// Supabase `auth.users.id` (UUID). Owns the user's synced rows.
  final String id;
  final String? email;
  final String? displayName;

  const AuthAccount({
    required this.id,
    this.email,
    this.displayName,
  });

  /// Best label for the UI: display name, else email, else a short id.
  String get label => displayName ?? email ?? id;

  @override
  bool operator ==(Object other) =>
      other is AuthAccount &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, email, displayName);

  @override
  String toString() =>
      'AuthAccount(id: $id, email: $email, displayName: $displayName)';
}
