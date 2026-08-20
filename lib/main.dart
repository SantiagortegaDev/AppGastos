/// Punto de entrada de la app AppGastos.
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
  // init() espera la respuesta del canal nativo para saber si viene del Tile.
  final launchedFromTile = await tileChannel.init();

  runApp(AppGastosApp(
    repository: repository,
    settingsService: settingsService,
    tileChannel: tileChannel,
    launchedFromTile: launchedFromTile,
  ));
}

class AppGastosApp extends StatelessWidget {
  final ExpenseRepository repository;
  final SettingsService settingsService;
  final TileChannel tileChannel;
  final bool launchedFromTile;

  const AppGastosApp({
    super.key,
    required this.repository,
    required this.settingsService,
    required this.tileChannel,
    required this.launchedFromTile,
  });

  @override
  Widget build(BuildContext context) {
    final s = settingsService;

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        // Cuando viene del Tile: fondo transparente para efecto overlay.
        final bgColor = launchedFromTile ? Colors.transparent : null;

        return MaterialApp(
          title: 'AppGastos',
          debugShowCheckedModeBanner: false,
          themeMode: s.settings.flutterThemeMode,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: bgColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: s.settings.seedColor,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: bgColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: s.settings.seedColor,
              brightness: Brightness.dark,
            ),
          ),
          home: HomeScreen(
            repository: repository,
            tileChannel: tileChannel,
            settingsService: s,
            launchedFromTile: launchedFromTile,
          ),
        );
      },
    );
  }
}
