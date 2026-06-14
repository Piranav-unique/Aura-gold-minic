import 'package:ags_gold/features/profile/domain/profile.dart';

enum ExecutiveRole { admin, manager, employee }

/// Resolves the executive dashboard persona from profile roles/permissions.
ExecutiveRole resolveExecutiveRole(UserProfile profile) {
  if (profile.isSuperuser) return ExecutiveRole.admin;

  final roleNames = profile.roles.map((r) => r.name).toSet();
  if (roleNames.contains('super_admin') || roleNames.contains('admin')) {
    return ExecutiveRole.admin;
  }
  if (roleNames.contains('manager')) return ExecutiveRole.manager;
  if (roleNames.contains('employee')) return ExecutiveRole.employee;

  final perms = profile.effectivePermissions;
  if (perms.contains('*') ||
      (perms.contains('audit.view') && perms.contains('transaction.view'))) {
    return ExecutiveRole.admin;
  }
  if (perms.contains('workflow.approve')) return ExecutiveRole.manager;
  return ExecutiveRole.employee;
}

String executiveRoleLabel(ExecutiveRole role) {
  switch (role) {
    case ExecutiveRole.admin:
      return 'Administrator';
    case ExecutiveRole.manager:
      return 'Manager';
    case ExecutiveRole.employee:
      return 'Employee';
  }
}
