import 'package:ags_gold/features/audit_logs/domain/audit_log.dart';
import 'package:ags_gold/features/notifications/domain/notification.dart';

class LoginStatistics {
  final int today;
  final int week;
  final int month;

  const LoginStatistics({
    required this.today,
    required this.week,
    required this.month,
  });

  factory LoginStatistics.fromJson(Map<String, dynamic> json) {
    return LoginStatistics(
      today: json['today'] as int? ?? 0,
      week: json['week'] as int? ?? 0,
      month: json['month'] as int? ?? 0,
    );
  }
}

class ActivityTrendPoint {
  final String label;
  final int count;

  const ActivityTrendPoint({required this.label, required this.count});

  factory ActivityTrendPoint.fromJson(Map<String, dynamic> json) {
    return ActivityTrendPoint(
      label: json['label'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

class DashboardStats {
  final List<AuditLog> recentActivity;
  final int unreadNotifications;
  final List<AuditLog> securityAlerts;
  final List<AppNotification> recentNotifications;
  final LoginStatistics loginStatistics;
  final List<ActivityTrendPoint> activityTrend;

  const DashboardStats({
    required this.recentActivity,
    required this.unreadNotifications,
    required this.securityAlerts,
    required this.recentNotifications,
    required this.loginStatistics,
    this.activityTrend = const [],
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      recentActivity: (json['recent_activity'] as List<dynamic>? ?? [])
          .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
          .toList(),
      unreadNotifications: json['unread_notifications'] as int? ?? 0,
      securityAlerts: (json['security_alerts'] as List<dynamic>? ?? [])
          .map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentNotifications:
          (json['recent_notifications'] as List<dynamic>? ?? [])
              .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
              .toList(),
      loginStatistics: LoginStatistics.fromJson(
        json['login_statistics'] as Map<String, dynamic>? ?? {},
      ),
      activityTrend: (json['activity_trend'] as List<dynamic>? ?? [])
          .map((e) => ActivityTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
