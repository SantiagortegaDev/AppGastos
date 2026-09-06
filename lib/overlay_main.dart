/// Entry point alternativo: ventana flotante para registrar un gasto/ingreso
/// sobre cualquier otra app, sin abrir la app completa.
///
/// Se lanza desde `OverlayActivity` (Android) con un `FlutterEngine` propio
/// cuyo dart entrypoint es `overlayMain`. Reutiliza exactamente el mismo
/// `AddExpenseSheet` que usa la app normal, así el diseño es idéntico.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/expense.dart';
import 'services/expense_repository.dart';
import 'services/settings_service.dart';
import 'widgets/add_expense_sheet.dart';

const MethodChannel _overlayChannel = MethodChannel('appgastos.dev/overlay');

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  _bootstrap();
}

Future<void> _bootstrap() async {
  final repository = ExpenseRepository();
  await repository.init();
  final settingsService = SettingsService();
  await settingsService.init();
  runApp(_OverlayApp(repository: repository, settingsService: settingsService));
}

class _OverlayApp extends StatelessWidget {
  final ExpenseRepository repository;
  final SettingsService settingsService;
  const _OverlayApp({required this.repository, required this.settingsService});

  @override
  Widget build(BuildContext context) {
    final s = settingsService.settings;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: s.flutterThemeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: s.seedColor, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: s.seedColor, brightness: Brightness.dark),
      ),
      home: _OverlayHost(repository: repository, settingsService: settingsService),
    );
  }
}

class _OverlayHost extends StatefulWidget {
  final ExpenseRepository repository;
  final SettingsService settingsService;
  const _OverlayHost({required this.repository, required this.settingsService});

  @override
  State<_OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<_OverlayHost> {
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet());
  }

  Future<void> _openSheet() async {
    if (_opened) return;
    _opened = true;

    String? typeStr;
    try {
      typeStr = await _overlayChannel.invokeMethod<String>('getOverlayType');
    } on PlatformException {
      typeStr = null;
    }
    final initialType = (typeStr != null && typeStr.isNotEmpty) ? TransactionType.fromName(typeStr) : null;

    final settings = widget.settingsService.settings;
    if (!mounted) return;
    // Reutiliza el mismo bottom sheet que usa la app: mismo diseño, mismos
    // pasos. showModalBottomSheet ya cierra al tocar fuera (barrierDismissible
    // por defecto) y al guardar (Navigator.pop(true) dentro del sheet).
    await AddExpenseSheet.show(
      context,
      widget.repository,
      settings,
      initialType: initialType,
      onExpenseSaved: (expense) async {
        final acc = expense.account;
        final newBalance = expense.type == TransactionType.ingreso
            ? acc.balance + expense.amount
            : acc.balance - expense.amount;
        await widget.settingsService.updateAccount(acc.id, balance: newBalance);
      },
    );
    await _finish();
  }

  Future<void> _finish() async {
    try {
      await _overlayChannel.invokeMethod<void>('finishOverlay');
    } on PlatformException {
      // Sin fallback: si el canal falla la Activity nativa queda abierta,
      // pero es un caso excepcional (canal roto).
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fondo totalmente transparente: lo único visible es el bottom sheet
    // (y su scrim) que dibuja AddExpenseSheet sobre la app de abajo.
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(),
    );
  }
}
