import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/logging/api_debug_log.dart';
import 'package:ags_gold/l10n/app_localizations.dart';
import 'package:ags_gold/config/env_config.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/app_exit_guard.dart';
import 'package:ags_gold/features/app_update/presentation/app_update_listener.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  installApiOnlyDebugLogging();

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
      builder: (context, child) => AppExitGuard(
        child: AppUpdateListener(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      title: 'AGS Gold',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
