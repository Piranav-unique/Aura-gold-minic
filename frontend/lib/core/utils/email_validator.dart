final RegExp _emailRegex = RegExp(
  r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$',
);

/// Return true if the email is a valid personal Gmail address ending in `@gmail.com`.
///
/// Customers must have a verified personal `@gmail.com` address for receiving official
/// tax invoices, payment receipts, and vault certificates.
bool isValidCustomerGmail(String? email) {
  if (email == null) return false;
  final cleaned = email.trim().toLowerCase();
  if (cleaned.isEmpty || !cleaned.contains('@')) return false;

  if (!_emailRegex.hasMatch(cleaned)) return false;

  // Must strictly end with @gmail.com
  if (!cleaned.endsWith('@gmail.com')) return false;

  // Placeholder containing agsgold
  if (cleaned.contains('agsgold')) return false;

  // Phone number used as local part (e.g. 7010196231@gmail.com)
  final localPart = cleaned.split('@').first;
  final digitsOnly = localPart.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length >= 10 &&
      (digitsOnly.length == localPart.length ||
          localPart.startsWith(digitsOnly))) {
    return false;
  }

  // Local part must have at least 3 characters
  if (localPart.length < 3) return false;

  return true;
}

/// Return true if the email is null, empty, invalid, or an auto-generated placeholder,
/// or not a valid personal `@gmail.com` address.
bool isPlaceholderEmail(String? email) {
  return !isValidCustomerGmail(email);
}

/// Form validator for user email input.
///
/// Returns null if valid, or a descriptive error message if invalid.
String? validateUserEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter your Gmail address.';
  }

  final cleaned = value.trim().toLowerCase();

  if (!_emailRegex.hasMatch(cleaned)) {
    return 'Enter a valid email address (e.g. name@gmail.com).';
  }

  if (!cleaned.endsWith('@gmail.com')) {
    return 'Email must end with @gmail.com (e.g. name@gmail.com).';
  }

  if (cleaned.contains('agsgold')) {
    return 'Please enter your personal Gmail address.';
  }

  final localPart = cleaned.split('@').first;
  final digitsOnly = localPart.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length >= 10 &&
      (digitsOnly.length == localPart.length ||
          localPart.startsWith(digitsOnly))) {
    return 'Please enter your personal Gmail address, not your mobile number.';
  }

  if (localPart.length < 3) {
    return 'Gmail username must be at least 3 characters.';
  }

  return null;
}
