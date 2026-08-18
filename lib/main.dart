/// Punto de entrada de la app AppGastos.
///
/// Inicializa el repositorio de persistencia y el canal de comunicación con
/// el TileService nativo, y arranca la UI Material 3.
library;

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/expense_repository.dart';
import 'services/tile_channel.dart';

void main() async {
  // Necesario para usar plugins (shared_preferences) antes de runApp().
  WidgetsFlutterBinding.ensureInitialized();

  final repository = ExpenseRepository();
  await repository.init();

  final tileChannel = TileChannel();
  tileChannel.init();

  runApp(AppGastosApp(
    repository: repository,
    tileChannel: tileChannel,
  ));
}

class AppGastosApp extends StatelessWidget {
  final ExpenseRepository repository;
  final TileChannel tileChannel;

  const AppGastosApp({
    super.key,
    required this.repository,
    required this.tileChannel,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppGastos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: HomeScreen(
        repository: repository,
        tileChannel: tileChannel,
      ),
    );
  }
}
