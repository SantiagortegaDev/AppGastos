/// Punto de entrada de la app AppGastos.
///

library;

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/expense_repository.dart';
import 'services/settings_service.dart';
import 'services/tile_channel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = ExpenseRepository();
  await repository.init();

  final settingsService = SettingsService();
  await settingsService.init();

  final tileChannel = TileChannel();
  await tileChannel.init();

  runApp(AppGastosApp(
    repository: repository,
    settingsService: settingsService,
    tileChannel: tileChannel,
  ));
}

class AppGastosApp extends StatelessWidget {
  final ExpenseRepository repository;
  final SettingsService settingsService;
  final TileChannel tileChannel;

  const AppGastosApp({
    super.key,
    required this.repository,
    required this.settingsService,
    required this.tileChannel,
  });

  @override
  Widget build(BuildContext context) {
    final s = settingsService;

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        return MaterialApp(
          title: 'AppGastos',
          debugShowCheckedModeBanner: false,
          themeMode: s.settings.flutterThemeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: s.settings.seedColor,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: s.settings.seedColor,
              brightness: Brightness.dark,
            ),
          ),
          home: HomeScreen(
            repository: repository,
            tileChannel: tileChannel,
            settingsService: s,
          ),
        );
      },
    );
  }
}
