import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/config/env_config.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/routes/app_routes.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/features/settings/presentation/providers/settings_provider.dart';

final appLocaleProvider = Provider<Locale?>((ref) {
  final auth = ref.watch(authNotifierProvider);
  if (auth.value != AuthStatus.authenticated) return null;
  return ref
      .watch(userSettingsProvider)
      .whenOrNull(
        data: (settings) {
          final code = settings.locale;
          if (code.isEmpty) return null;
          return Locale(code.split('_').first);
        },
      );
});

void main() {
  assert(
    Uri.tryParse(EnvConfig.active.baseUrl)?.hasAbsolutePath ?? false,
    'Invalid API Base URL configured. Check EnvConfig parameters.',
  );

  runApp(const ProviderScope(child: AGSGoldApp()));
}

class AGSGoldApp extends ConsumerWidget {
  const AGSGoldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      title: 'AGS Gold',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('es'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
