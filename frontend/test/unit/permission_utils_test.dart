import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';

final _superuser = UserProfile(
  id: '1',
  mobileNumber: '9876543210',
  isActive: true,
  isSuperuser: true,
  createdAt: DateTime.utc(2026, 6, 8),
  updatedAt: DateTime.utc(2026, 6, 8),
);

final _viewer = UserProfile(
  id: '2',
  mobileNumber: '9876543210',
  isActive: true,
  isSuperuser: false,
  roles: const [
    UserRole(
      id: 'r1',
      name: 'Viewer',
      permissions: [UserPermission(id: 'p1', name: 'customer.view')],
    ),
  ],
  createdAt: DateTime.utc(2026, 6, 8),
  updatedAt: DateTime.utc(2026, 6, 8),
);

void main() {
  test('hasPermission grants superuser all access', () {
    expect(hasPermission(_superuser, 'customer.delete'), isTrue);
  });

  test('hasPermission checks explicit permission', () {
    expect(hasPermission(_viewer, 'customer.view'), isTrue);
    expect(hasPermission(_viewer, 'customer.create'), isFalse);
  });
}
