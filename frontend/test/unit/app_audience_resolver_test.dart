import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/auth/domain/app_audience.dart';
import 'package:ags_gold/features/auth/domain/app_audience_resolver.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';

UserProfile _profile({
  String? mobileNumber,
  bool isSuperuser = false,
  List<UserRole> roles = const [],
}) {
  return UserProfile(
    id: 'user-1',
    mobileNumber: mobileNumber,
    isActive: true,
    isSuperuser: isSuperuser,
    roles: roles,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  test('admin mobile resolves to staff dashboard audience', () {
    final audience = resolveAppAudience(
      profile: _profile(mobileNumber: '9943795005', isSuperuser: true),
      adminMobile: '9943795005',
      mobileHint: '9943795005',
    );

    expect(audience, AppAudience.staffAdmin);
  });

  test('regular consumer mobile resolves to end-user audience', () {
    final audience = resolveAppAudience(
      profile: _profile(mobileNumber: '8015915867'),
      adminMobile: '9943795005',
      mobileHint: '8015915867',
    );

    expect(audience, AppAudience.endUser);
  });
}
