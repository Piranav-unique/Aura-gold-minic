import 'package:flutter/services.dart';

/// Formatter for mobile phone numbers that cleanly handles paste events
/// (including formatted numbers like "+91 99437 95005", "99437-95005", "Call 9943795005")
/// and standard typing, extracting and retaining valid numeric digits.
class PasteAwarePhoneFormatter extends TextInputFormatter {
  final int maxLength;

  PasteAwarePhoneFormatter({this.maxLength = 10});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final isPaste = (newValue.text.length - oldValue.text.length).abs() > 1;

    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Strip leading +91 or 91 if the number was entered with country code
    if (digits.length > maxLength && digits.startsWith('91')) {
      digits = digits.substring(2);
    }

    // Limit to maxLength digits
    if (digits.length > maxLength) {
      digits = digits.substring(0, maxLength);
    }

    int cursorOffset;
    if (isPaste) {
      cursorOffset = digits.length;
    } else {
      final nonDigitsBeforeCursor = newValue.selection.baseOffset > 0
          ? newValue.text
              .substring(
                0,
                newValue.selection.baseOffset.clamp(0, newValue.text.length),
              )
              .replaceAll(RegExp(r'\d'), '')
              .length
          : 0;
      cursorOffset = (newValue.selection.baseOffset - nonDigitsBeforeCursor)
          .clamp(0, digits.length);
    }

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }
}

/// Formatter for OTP fields that extracts digits even when pasted from SMS
/// or clipboard containing spaces/dashes/prefixes.
class PasteAwareOtpFormatter extends TextInputFormatter {
  final int maxLength;

  PasteAwareOtpFormatter({this.maxLength = 6});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final isPaste = (newValue.text.length - oldValue.text.length).abs() > 1;

    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > maxLength) {
      digits = digits.substring(0, maxLength);
    }

    int cursorOffset;
    if (isPaste) {
      cursorOffset = digits.length;
    } else {
      cursorOffset = newValue.selection.baseOffset.clamp(0, digits.length);
    }

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }
}
