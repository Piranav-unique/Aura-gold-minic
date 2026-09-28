import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/core/utils/email_validator.dart';

void main() {
  group('isPlaceholderEmail', () {
    test('identifies null and empty strings as invalid/placeholder', () {
      expect(isPlaceholderEmail(null), isTrue);
      expect(isPlaceholderEmail(''), isTrue);
      expect(isPlaceholderEmail('   '), isTrue);
    });

    test('identifies malformed emails as placeholder/invalid', () {
      expect(isPlaceholderEmail('notanemail'), isTrue);
      expect(isPlaceholderEmail('missing@domain'), isTrue);
      expect(isPlaceholderEmail('@nodomain.com'), isTrue);
    });

    test('identifies system-generated mobile signup placeholders', () {
      expect(isPlaceholderEmail('7010196231@mobile.agsgold.com'), isTrue);
      expect(isPlaceholderEmail('9442733154@mobile.agsgold.com'), isTrue);
      expect(isPlaceholderEmail('test@agsgold.com'), isTrue);
    });

    test('identifies custom agsgold or phoneno placeholders', () {
      expect(isPlaceholderEmail('phoneno.agsgold@gmail.com'), isTrue);
      expect(isPlaceholderEmail('7010196231.agsgold@gmail.com'), isTrue);
      expect(isPlaceholderEmail('agsgold_user@yahoo.com'), isTrue);
    });

    test('identifies phone numbers as email usernames', () {
      expect(isPlaceholderEmail('7010196231@gmail.com'), isTrue);
      expect(isPlaceholderEmail('9442733154@outlook.com'), isTrue);
    });

    test('accepts valid personal and academic emails', () {
      expect(isPlaceholderEmail('piranav.richu2006@gmail.com'), isFalse);
      expect(isPlaceholderEmail('nathan@student.tce.edu'), isFalse);
      expect(isPlaceholderEmail('name.someone@gmail.com'), isFalse);
      expect(isPlaceholderEmail('john.doe@company.org'), isFalse);
    });
  });

  group('validateUserEmail', () {
    test('returns error for empty or invalid emails', () {
      expect(validateUserEmail(''), isNotNull);
      expect(validateUserEmail('invalid'), isNotNull);
    });

    test('rejects agsgold and phone-based placeholders', () {
      expect(validateUserEmail('phoneno.agsgold@gmail.com'), isNotNull);
      expect(validateUserEmail('7010196231@gmail.com'), isNotNull);
      expect(validateUserEmail('user@mobile.agsgold.com'), isNotNull);
    });

    test('returns null for valid personal emails', () {
      expect(validateUserEmail('name.someone@gmail.com'), isNull);
      expect(validateUserEmail('piranav.richu2006@gmail.com'), isNull);
      expect(validateUserEmail('nathan@student.tce.edu'), isNull);
    });
  });
}
