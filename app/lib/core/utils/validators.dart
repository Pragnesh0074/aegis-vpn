/// Client-side form rules, kept deliberately identical to the backend DTOs in
/// `backend/src/auth/dto/`. Validating here is a courtesy — the server is still
/// the authority, and its 400 messages are surfaced verbatim when they disagree.
abstract final class Validators {
  /// Matches `@IsEmail()` closely enough for a form: one `@`, a dot in the domain,
  /// no spaces. Anything subtler is left to the server.
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// `MinLength(10)` on RegisterDto. There are no composition rules on purpose:
  /// length beats character classes.
  static const passwordMinLength = 10;
  static const passwordMaxLength = 128;
  static const emailMaxLength = 254;

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Email is required';
    if (input.length > emailMaxLength) return 'Email is too long';
    if (!_email.hasMatch(input)) return 'Enter a valid email address';
    return null;
  }

  /// For sign-in, where the length rule does not apply — an existing account may
  /// predate it, and rejecting locally would lock the user out of their own app.
  static String? requiredPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length > passwordMaxLength) return 'Password is too long';
    return null;
  }

  /// For registration, which must satisfy RegisterDto.
  static String? newPassword(String? value) {
    final required = requiredPassword(value);
    if (required != null) return required;
    if (value!.length < passwordMinLength) {
      return 'Password must be at least $passwordMinLength characters';
    }
    return null;
  }

  /// `MinLength(1) MaxLength(64)` on CreateDeviceDto.name.
  static String? deviceName(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Device name is required';
    if (input.length > 64) return 'Device name must be 64 characters or fewer';
    return null;
  }
}
