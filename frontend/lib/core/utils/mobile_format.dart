/// Formats a stored mobile number for display (e.g. +91 98765 43210).
String formatDisplayMobile(String? raw) {
  if (raw == null || raw.isEmpty) return '';

  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    digits = digits.substring(2);
  }
  if (digits.length == 10) {
    return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
  }
  if (raw.startsWith('+')) return raw;
  return digits.isEmpty ? raw : '+$digits';
}
