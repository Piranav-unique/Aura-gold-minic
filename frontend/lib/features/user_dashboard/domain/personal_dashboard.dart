import 'package:ags_gold/core/utils/mobile_format.dart';
import 'package:ags_gold/features/dashboard/domain/dashboard_stats.dart';
import 'package:ags_gold/features/dashboard/domain/executive_dashboard.dart';
import 'package:ags_gold/features/notifications/domain/notification.dart';
import 'package:ags_gold/features/user_dashboard/domain/gold_scheme.dart';
import 'package:ags_gold/features/user_dashboard/domain/kyc_status.dart';

class PersonalDashboard {
  final String displayName;
  final String? mobileNumber;
  final List<String> roles;
  final int unreadNotifications;
  final DateTime refreshedAt;
  final LoginStatistics loginStatistics;
  final List<ActivityTrendPoint> activityTrend;
  final List<AppNotification> recentNotifications;
  final List<AssignedTaskSummary> assignedTasks;
  final List<DailyActivityItem> dailyActivities;
  final int pendingTaskCount;
  final int draftTaskCount;
  final KycStatus kycStatus;
  final KycGovernmentProfile? kycProfile;
  final double goldSavingsGrams;
  final double silverSavingsGrams;
  final double goldInvestedInr;
  final double silverInvestedInr;
  final double walletBalanceInr;
  final GoldScheme goldScheme;

  const PersonalDashboard({
    required this.displayName,
    this.mobileNumber,
    required this.roles,
    required this.unreadNotifications,
    required this.refreshedAt,
    required this.loginStatistics,
    this.activityTrend = const [],
    this.recentNotifications = const [],
    this.assignedTasks = const [],
    this.dailyActivities = const [],
    this.pendingTaskCount = 0,
    this.draftTaskCount = 0,
    this.kycStatus = KycStatus.notStarted,
    this.kycProfile,
    this.goldSavingsGrams = 0,
    this.silverSavingsGrams = 0,
    this.goldInvestedInr = 0,
    this.silverInvestedInr = 0,
    this.walletBalanceInr = 0,
    this.goldScheme = const GoldScheme(),
  });

  factory PersonalDashboard.fromJson(Map<String, dynamic> json) {
    return PersonalDashboard(
      displayName: json['display_name'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String?,
      roles: (json['roles'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      unreadNotifications: json['unread_notifications'] as int? ?? 0,
      refreshedAt: DateTime.parse(json['refreshed_at'] as String),
      loginStatistics: LoginStatistics.fromJson(
        json['login_statistics'] as Map<String, dynamic>? ?? {},
      ),
      activityTrend: (json['activity_trend'] as List<dynamic>? ?? [])
          .map((e) => ActivityTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentNotifications:
          (json['recent_notifications'] as List<dynamic>? ?? [])
              .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
              .toList(),
      assignedTasks: (json['assigned_tasks'] as List<dynamic>? ?? [])
          .map(
            (e) => AssignedTaskSummary.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      dailyActivities: (json['daily_activities'] as List<dynamic>? ?? [])
          .map((e) => DailyActivityItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingTaskCount: json['pending_task_count'] as int? ?? 0,
      draftTaskCount: json['draft_task_count'] as int? ?? 0,
      kycStatus: KycStatus.fromValue(json['kyc_status'] as String?),
      kycProfile: KycGovernmentProfile.fromJson(
        json['kyc_profile'] as Map<String, dynamic>?,
      ),
      goldSavingsGrams: _parseDecimal(json['gold_savings_grams']),
      silverSavingsGrams: _parseDecimal(json['silver_savings_grams']),
      goldInvestedInr: _parseDecimal(json['gold_invested_inr']),
      silverInvestedInr: _parseDecimal(json['silver_invested_inr']),
      walletBalanceInr: _parseDecimal(json['wallet_balance_inr']),
      goldScheme: GoldScheme.fromJson(
        json['gold_scheme'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  String get displayContactLine => formatDisplayMobile(mobileNumber);

  String get primaryRoleLabel {
    if (roles.isEmpty) return 'User';
    final primary = roles.first;
    return primary
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

double _parseDecimal(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
