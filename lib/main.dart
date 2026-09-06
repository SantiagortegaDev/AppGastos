/// Punto de entrada — navegación con 3 tabs.
library;

import 'package:flutter/material.dart';
import 'screens/debts_screen.dart';
import 'screens/home_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/search_screen.dart';
import 'services/debt_repository.dart';
import 'services/expense_repository.dart';
import 'services/notification_service.dart';
import 'services/payment_watch_service.dart';
import 'services/settings_service.dart';
import 'services/tile_channel.dart';
// ignore: unused_import
import 'overlay_main.dart'; // Mantiene overlayMain() alcanzable para el build AOT (lo usa OverlayActivity).

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = ExpenseRepository();
  await repository.init();
  final debtRepository = DebtRepository();
  await debtRepository.init();
  final settingsService = SettingsService();
  await settingsService.init();
  final paymentWatchService = PaymentWatchService();
  await paymentWatchService.init();
  final tileChannel = TileChannel();
  await tileChannel.init();
  await NotificationService.instance.init();
  await NotificationService.instance.scheduleRegisterReminder(
    enabled: settingsService.settings.reminderEnabled,
    days: settingsService.settings.reminderDays,
  );

  runApp(AppGastosApp(
    repository: repository,
    debtRepository: debtRepository,
    settingsService: settingsService,
    paymentWatchService: paymentWatchService,
    tileChannel: tileChannel,
  ));
}

class AppGastosApp extends StatelessWidget {
  final ExpenseRepository repository;
  final DebtRepository debtRepository;
  final SettingsService settingsService;
  final PaymentWatchService paymentWatchService;
  final TileChannel tileChannel;

  const AppGastosApp({
    super.key,
    required this.repository,
    required this.debtRepository,
    required this.settingsService,
    required this.paymentWatchService,
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
          onGenerateRoute: (settings) {
            if (settings.name == '/search') {
              return MaterialPageRoute(
                builder: (_) => SearchScreen(
                  repository: repository,
                  settingsService: s,
                ),
              );
            }
            return null;
          },
          home: MainShell(
            repository: repository,
            debtRepository: debtRepository,
            settingsService: s,
            paymentWatchService: paymentWatchService,
            tileChannel: tileChannel,
          ),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  final ExpenseRepository repository;
  final DebtRepository debtRepository;
  final SettingsService settingsService;
  final PaymentWatchService paymentWatchService;
  final TileChannel tileChannel;
  const MainShell({
    super.key,
    required this.repository,
    required this.debtRepository,
    required this.settingsService,
    required this.paymentWatchService,
    required this.tileChannel,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(
            repository: widget.repository,
            tileChannel: widget.tileChannel,
            settingsService: widget.settingsService,
          ),
          StatsScreen(
            repository: widget.repository,
            settingsService: widget.settingsService,
          ),
          DebtsScreen(
            repository: widget.debtRepository,
            currency: widget.settingsService.settings.currency,
          ),
          SettingsScreen(
            settingsService: widget.settingsService,
            paymentWatchService: widget.paymentWatchService,
            tileChannel: widget.tileChannel,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_filled),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Graficos',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake),
            label: 'Deudas',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}