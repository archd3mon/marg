import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  const MargApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = createRouter(storage);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Marg',
      debugShowCheckedModeBanner: false,
      theme: margTheme(Brightness.light),
      darkTheme: margTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
