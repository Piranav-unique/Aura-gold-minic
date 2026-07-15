import 'package:ags_gold/features/auth/domain/app_audience.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';

const _staffRoleNames = {'super_admin', 'admin', 'manager', 'employee'};

String normalizeIndianMobile(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    return digits.substring(2);
  }
  return digits;
}

bool isStaffProfile(UserProfile profile) {
  if (profile.isSuperuser) return true;
  return profile.roles.any((role) => _staffRoleNames.contains(role.name));
}

AppAudience resolveAppAudience({
  required UserProfile profile,
  required String adminMobile,
  String? mobileHint,
}) {
  final admin = normalizeIndianMobile(adminMobile);
  final hinted = mobileHint != null ? normalizeIndianMobile(mobileHint) : null;
  final profileMobile = profile.mobileNumber == null
      ? null
      : normalizeIndianMobile(profile.mobileNumber!);

  if (profileMobile == admin || hinted == admin) {
    return AppAudience.staffAdmin;
  }
  if (isStaffProfile(profile)) {
    return AppAudience.staffAdmin;
  }
  return AppAudience.endUser;
}
