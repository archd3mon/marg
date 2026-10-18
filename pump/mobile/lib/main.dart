import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/config_error_screen.dart';
import 'app/config_validator.dart';
import 'app/health_gate.dart';
import 'app/router.dart';
import 'app/app_state.dart';
import 'data/storage_service.dart';
import 'theme/marg_tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
      child: MargApp(storage: storage),
    ),
  );
}

class MargApp extends ConsumerWidget {
  final StorageService storage;
  final String? apiBaseOverride;
  final bool? isReleaseOverride;

  const MargApp({
    super.key,
    required this.storage,
    this.apiBaseOverride,
    this.isReleaseOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    final configError = ConfigValidator.validateApiBase(
      apiBase: apiBaseOverride,
      isRelease: isReleaseOverride ?? kReleaseMode,
    );

    if (configError != null) {
      return MaterialApp(
        title: 'Marg Configuration Error',
        debugShowCheckedModeBanner: false,
        theme: margTheme(Brightness.light),
        darkTheme: margTheme(Brightness.dark),
        themeMode: themeMode,
        home: ConfigErrorScreen(message: configError),
      );
    }

    final router = createRouter(storage);

    return MaterialApp.router(
      title: 'Marg',
      debugShowCheckedModeBanner: false,
      theme: margTheme(Brightness.light),
      darkTheme: margTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => HealthGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

