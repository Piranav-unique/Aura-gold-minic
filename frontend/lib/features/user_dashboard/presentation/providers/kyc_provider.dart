import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/auth/domain/app_audience.dart';
import 'package:ags_gold/features/auth/presentation/providers/app_audience_provider.dart';
import 'package:ags_gold/features/user_dashboard/domain/kyc_status.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/services/service_providers.dart';

final kycStatusProvider = FutureProvider.autoDispose<KycStatusDetails>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/profile/kyc/status');
  return KycStatusDetails.fromJson(response.data as Map<String, dynamic>);
});

/// Cached KYC gate used by app routing for end-user onboarding.
/// Prefer the live KYC status endpoint so the UI updates immediately after
/// verification, even when the personal dashboard response is still cached.
final effectiveKycCompleteProvider = Provider<bool>((ref) {
  final fromKyc = ref.watch(kycStatusProvider).value?.status.isComplete;
  if (fromKyc == true) return true;
  if (fromKyc != null) return fromKyc;
  return ref.watch(personalDashboardProvider).value?.kycStatus.isComplete ??
      false;
});

/// KYC status for trading and profile UI; prefers [kycStatusProvider].
final effectiveKycStatusProvider = Provider<KycStatus>((ref) {
  final fromKyc = ref.watch(kycStatusProvider).value?.status;
  if (fromKyc != null) return fromKyc;
  return ref.watch(personalDashboardProvider).value?.kycStatus ??
      KycStatus.notStarted;
});

final userKycGateProvider = FutureProvider<KycStatusDetails?>((ref) async {
  final auth = await ref.watch(authNotifierProvider.future);
  if (auth != AuthStatus.authenticated) return null;
  final audience = ref.watch(appAudienceProvider);
  if (audience != AppAudience.endUser) return null;
  return ref.watch(kycStatusProvider.future);
});

final kycAadhaarOtpProvider = Provider((ref) {
  return (String aadhaarNumber) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.post(
      '/profile/kyc/aadhaar/otp',
      data: {'aadhaar_number': aadhaarNumber},
    );
    final data = response.data as Map<String, dynamic>;
    return (
      referenceId: data['reference_id'] as String,
      registeredMobileMasked: data['registered_mobile_masked'] as String?,
    );
  };
});

final kycAadhaarVerifyProvider = Provider((ref) {
  return ({
    required String referenceId,
    required String otp,
    required String aadhaarNumber,
  }) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.post(
      '/profile/kyc/aadhaar/verify',
      data: {
        'reference_id': referenceId,
        'otp': otp,
        'aadhaar_number': aadhaarNumber,
      },
    );
    return KycStatusDetails.fromJson(response.data as Map<String, dynamic>);
  };
});

final kycPanVerifyProvider = Provider((ref) {
  return (String panNumber) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.post(
      '/profile/kyc/pan/verify',
      data: {'pan_number': panNumber},
    );
    return KycStatusDetails.fromJson(response.data as Map<String, dynamic>);
  };
});
