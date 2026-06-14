import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/features/settings/domain/user_settings.dart';

void main() {
  test('UserSettings toJson and copyWith', () {
    const settings = UserSettings(locale: 'en');
    final updated = settings.copyWith(
      locale: 'es',
      notificationEmailEnabled: false,
    );
    expect(updated.locale, 'es');
    expect(updated.notificationEmailEnabled, false);
    expect(updated.toJson()['locale'], 'es');
  });

  test('UserSettings.fromJson uses defaults', () {
    final settings = UserSettings.fromJson({'locale': 'fr'});
    expect(settings.locale, 'fr');
    expect(settings.notificationPushEnabled, true);
  });
}
