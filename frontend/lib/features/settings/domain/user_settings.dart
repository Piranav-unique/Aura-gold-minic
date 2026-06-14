class UserSettings {
  final String locale;
  final bool notificationEmailEnabled;
  final bool notificationPushEnabled;
  final bool notificationSecurityAlerts;
  final bool notificationSystemUpdates;

  const UserSettings({
    this.locale = 'en',
    this.notificationEmailEnabled = true,
    this.notificationPushEnabled = true,
    this.notificationSecurityAlerts = true,
    this.notificationSystemUpdates = true,
  });

  UserSettings copyWith({
    String? locale,
    bool? notificationEmailEnabled,
    bool? notificationPushEnabled,
    bool? notificationSecurityAlerts,
    bool? notificationSystemUpdates,
  }) {
    return UserSettings(
      locale: locale ?? this.locale,
      notificationEmailEnabled:
          notificationEmailEnabled ?? this.notificationEmailEnabled,
      notificationPushEnabled:
          notificationPushEnabled ?? this.notificationPushEnabled,
      notificationSecurityAlerts:
          notificationSecurityAlerts ?? this.notificationSecurityAlerts,
      notificationSystemUpdates:
          notificationSystemUpdates ?? this.notificationSystemUpdates,
    );
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      locale: json['locale'] as String? ?? 'en',
      notificationEmailEnabled:
          json['notification_email_enabled'] as bool? ?? true,
      notificationPushEnabled:
          json['notification_push_enabled'] as bool? ?? true,
      notificationSecurityAlerts:
          json['notification_security_alerts'] as bool? ?? true,
      notificationSystemUpdates:
          json['notification_system_updates'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'locale': locale,
      'notification_email_enabled': notificationEmailEnabled,
      'notification_push_enabled': notificationPushEnabled,
      'notification_security_alerts': notificationSecurityAlerts,
      'notification_system_updates': notificationSystemUpdates,
    };
  }
}
