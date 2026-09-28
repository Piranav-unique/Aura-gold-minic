final RegExp _emailRegex = RegExp(
  r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$',
);

/// Return true if the email is null, empty, invalid, or an auto-generated placeholder.
///
/// Placeholders include:
/// - `@mobile.agsgold.com` or `@agsgold.com` (system auto-generated mobile signup)
/// - Any email containing `agsgold` (e.g. `phoneno.agsgold@gmail.com`)
/// - Any email whose local part is a phone number (10 or more digits)
bool isPlaceholderEmail(String? email) {
  if (email == null) return true;
  final cleaned = email.trim().toLowerCase();
  if (cleaned.isEmpty || !cleaned.contains('@')) return true;

  if (!_emailRegex.hasMatch(cleaned)) return true;

  // System generated domain
  if (cleaned.endsWith('@mobile.agsgold.com') ||
      cleaned.endsWith('@agsgold.com')) {
    return true;
  }

  // Placeholder containing agsgold
  if (cleaned.contains('agsgold')) {
    return true;
  }

  // Phone number used as local part (e.g. 7010196231@gmail.com)
  final localPart = cleaned.split('@').first;
  final digitsOnly = localPart.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length >= 10 &&
      (digitsOnly.length == localPart.length ||
          localPart.startsWith(digitsOnly))) {
    return true;
  }

  return false;
}

/// Form validator for user email input.
///
/// Returns null if valid, or a descriptive error message if invalid.
String? validateUserEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter your email address.';
  }

  final cleaned = value.trim().toLowerCase();

  if (!_emailRegex.hasMatch(cleaned)) {
    return 'Enter a valid email address (e.g. name@gmail.com).';
  }

  if (cleaned.endsWith('@mobile.agsgold.com') ||
      cleaned.endsWith('@agsgold.com') ||
      cleaned.contains('agsgold')) {
    return 'Please enter your personal email address (e.g. name@gmail.com).';
  }

  final localPart = cleaned.split('@').first;
  final digitsOnly = localPart.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length >= 10 &&
      (digitsOnly.length == localPart.length ||
          localPart.startsWith(digitsOnly))) {
    return 'Please enter your personal email, not your mobile number.';
  }

  return null;
}
