import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';

import 'core/providers/last_module_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/catalog_sync_service.dart';
import 'core/services/supabase_config.dart';
import 'core/services/user_data_sync_coordinator.dart';
import 'core/theme/athlos_theme.dart';
import 'core/theme/theme_mode_provider.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  final prefs = await SharedPreferences.getInstance();

  if (isSupabaseConfigured) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  if (isSupabaseConfigured) {
    container.read(catalogSyncServiceProvider).sync();
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const AthlosApp()),
  );
}

class AthlosApp extends ConsumerStatefulWidget {
  const AthlosApp({super.key});

  @override
  ConsumerState<AthlosApp> createState() => _AthlosAppState();
}

class _AthlosAppState extends ConsumerState<AthlosApp> {
  late final AppLifecycleListener _appLifecycleListener;

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
      onExitRequested: () async => AppExitResponse.cancel,
      onResume: () {
        if (!isSupabaseConfigured) return;
        unawaited(
          ref.read(userDataSyncCoordinatorProvider).retryPendingUserDataSync(),
        );
      },
    );
  }

  @override
  void dispose() {
    _appLifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Athlos',
      debugShowCheckedModeBanner: false,
      theme: AthlosTheme.light,
      darkTheme: AthlosTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: child,
        );
      },
    );
  }
}
