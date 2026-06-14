import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/dashboard/domain/executive_dashboard.dart';
import 'package:ags_gold/features/dashboard/presentation/providers/executive_dashboard_provider.dart';
import 'package:ags_gold/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/services/service_providers.dart';

final dashboardTestProfile = UserProfile(
  id: '11111111-1111-1111-1111-111111111111',
  email: 'test@agsgold.com',
  firstName: 'Test',
  lastName: 'User',
  isActive: true,
  isSuperuser: true,
  createdAt: DateTime.utc(2026, 6, 8),
  updatedAt: DateTime.utc(2026, 6, 8),
);

ExecutiveDashboard dashboardTestExecutive({String role = 'admin'}) {
  return ExecutiveDashboard(
    role: role,
    displayName: 'Test User',
    unreadNotifications: 0,
    refreshedAt: DateTime.utc(2026, 6, 8, 10),
  );
}

/// Shared provider overrides for auth flows that land on the dashboard.
final authDashboardTestOverrides = [
  profileProvider.overrideWith((ref) async => dashboardTestProfile),
  executiveDashboardProvider.overrideWith(
    (ref) => Stream.value(dashboardTestExecutive()),
  ),
  unreadNotificationsCountProvider.overrideWithValue(
    const AsyncValue.data(0),
  ),
];
