/// Mirrors the `user_role` Postgres enum from Module 7's schema.
/// Sourced from the JWT `role` claim (see custom_access_token_hook, Module 7 §9).
enum UserRole {
  superAdmin,
  owner,
  staff;

  static UserRole fromString(String value) {
    switch (value) {
      case 'super_admin':
        return UserRole.superAdmin;
      case 'owner':
        return UserRole.owner;
      case 'staff':
        return UserRole.staff;
      default:
        throw ArgumentError('Unknown role: $value');
    }
  }
}
