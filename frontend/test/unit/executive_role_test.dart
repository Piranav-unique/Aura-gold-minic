import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/core/auth/executive_role.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';

UserProfile _profile({
  bool superuser = false,
  List<UserRole> roles = const [],
}) {
  return UserProfile(
    id: '1',
    mobileNumber: '9876543210',
    isActive: true,
    isSuperuser: superuser,
    roles: roles,
    createdAt: DateTime.utc(2026, 6, 8),
    updatedAt: DateTime.utc(2026, 6, 8),
  );
}

UserRole _role(String name, [List<String> permissions = const []]) {
  return UserRole(
    id: name,
    name: name,
    permissions: permissions
        .map((p) => UserPermission(id: p, name: p))
        .toList(),
  );
}

void main() {
  test('resolveExecutiveRole maps superuser to admin', () {
    expect(resolveExecutiveRole(_profile(superuser: true)), ExecutiveRole.admin);
  });

  test('resolveExecutiveRole maps named roles', () {
    expect(
      resolveExecutiveRole(_profile(roles: [_role('manager')])),
      ExecutiveRole.manager,
    );
    expect(
      resolveExecutiveRole(_profile(roles: [_role('employee')])),
      ExecutiveRole.employee,
    );
    expect(
      resolveExecutiveRole(_profile(roles: [_role('admin')])),
      ExecutiveRole.admin,
    );
  });

  test('resolveExecutiveRole uses permission heuristics', () {
    expect(
      resolveExecutiveRole(
        _profile(roles: [_role('custom', ['audit.view', 'transaction.view'])]),
      ),
      ExecutiveRole.admin,
    );
    expect(
      resolveExecutiveRole(
        _profile(roles: [_role('custom', ['workflow.approve'])]),
      ),
      ExecutiveRole.manager,
    );
    expect(
      resolveExecutiveRole(_profile(roles: [_role('custom', ['user.view'])])),
      ExecutiveRole.employee,
    );
  });

  test('executiveRoleLabel returns readable labels', () {
    expect(executiveRoleLabel(ExecutiveRole.admin), 'Administrator');
    expect(executiveRoleLabel(ExecutiveRole.manager), 'Manager');
    expect(executiveRoleLabel(ExecutiveRole.employee), 'Employee');
  });
}
