import 'package:shared_preferences/shared_preferences.dart';

/// Local KYC draft keys (Aadhaar OTP in progress). Cleared on logout/delete.
abstract final class KycDraftPrefs {
  static const referenceIdKey = 'kyc_aadhaar_reference_id';
  static const otpSentKey = 'kyc_aadhaar_otp_sent';
  static const aadhaarPendingKey = 'kyc_aadhaar_pending';

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(referenceIdKey);
    await prefs.setBool(otpSentKey, false);
    await prefs.remove(aadhaarPendingKey);
  }
}
