import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';

void main() {
  test('UserProfile.fromJson and effectivePermissions', () {
    final profile = UserProfile.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'email': 'user@example.com',
      'first_name': 'Jane',
      'last_name': 'Doe',
      'is_active': true,
      'is_superuser': false,
      'roles': [
        {
          'id': '22222222-2222-2222-2222-222222222222',
          'name': 'admin',
          'permissions': [
            {'id': '33333333-3333-3333-3333-333333333333', 'name': 'user.view'},
          ],
        },
      ],
      'created_at': '2026-06-08T10:00:00Z',
      'updated_at': '2026-06-08T10:00:00Z',
    });

    expect(profile.displayName, 'Jane Doe');
    expect(profile.effectivePermissions, contains('user.view'));
  });
}
