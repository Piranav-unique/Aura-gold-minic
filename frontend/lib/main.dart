import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/config/env_config.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/routes/app_routes.dart';
import 'package:ags_gold/services/service_providers.dart';

void main() {
  // Assert environment configurations at boot time
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

    return MaterialApp.router(
      title: 'AGS Gold',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
