/// Pantalla de ajustes completa.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_settings.dart';
import '../models/currency.dart';
import '../models/budget.dart';
import '../models/account.dart';
import '../models/expense.dart';
import '../services/settings_service.dart';
import '../widgets/section_card.dart';
import '../widgets/color_picker_widget.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  const SettingsScreen({super.key, required this.settingsService});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _webhookCtrl;
  late TextEditingController _apiUrlCtrl;
  late TextEditingController _apiTokenCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.settingsService.settings;
    _webhookCtrl = TextEditingController(text: s.webhookUrl);
    _apiUrlCtrl = TextEditingController(text: s.apiBaseUrl);
    _apiTokenCtrl = TextEditingController(text: s.apiToken);
  }

  @override
  void dispose() {
    _webhookCtrl.dispose();
    _apiUrlCtrl.dispose();
    _apiTokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settingsService;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final c = s.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('Ajustes')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _sectionApariencia(s, c),
              const SizedBox(height: 12),
              _sectionBilleteras(s, c),
              const SizedBox(height: 12),
              _sectionRegistro(s, c),
              const SizedBox(height: 12),
              _sectionMoneda(s, c),
              const SizedBox(height: 12),
              _sectionPresupuestos(s, c),
              const SizedBox(height: 12),
              _sectionAccesoRapido(),
              const SizedBox(height: 12),
              _sectionSeguridad(s, c),
              const SizedBox(height: 12),
              _sectionWebhook(s, c),
              const SizedBox(height: 12),
              _sectionApi(s, c),
              const SizedBox(height: 12),
              _sectionExportar(),
              const SizedBox(height: 12),
              _sectionAcercaDe(),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────── SECCIONES ──────────────────────────

  Widget _sectionApariencia(SettingsService s, AppSettings c) {
    return SectionCard(title: 'Apariencia', icon: Icons.palette_outlined, children: [
      ListTile(
        leading: const Icon(Icons.brightness_6_outlined),
        title: const Text('Tema'),
        trailing: SegmentedButton<AppThemeMode>(
          segments: const [
            ButtonSegment(value: AppThemeMode.light, icon: Icon(Icons.light_mode_outlined)),
            ButtonSegment(value: AppThemeMode.system, icon: Icon(Icons.settings_brightness)),
            ButtonSegment(value: AppThemeMode.dark, icon: Icon(Icons.dark_mode_outlined)),
          ],
          selected: {c.themeMode},
          onSelectionChanged: (sel) => s.setThemeMode(sel.first),
        ),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text('Color de la app', style: Theme.of(context).textTheme.titleSmall),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Wrap(
          spacing: 12, runSpacing: 12,
          children: kColorPalettes.map((p) {
            final sel = c.seedColor.value == p.color.value;
            return GestureDetector(
              onTap: () => s.setSeedColor(p.color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: p.color, shape: BoxShape.circle,
                  border: Border.all(color: sel ? Theme.of(context).colorScheme.onSurface : Colors.transparent, width: 3),
                  boxShadow: sel ? [BoxShadow(color: p.color.withValues(alpha: 0.4), blurRadius: 10)] : null,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _sectionBilleteras(SettingsService s, AppSettings c) {
    return SectionCard(title: 'Billeteras', icon: Icons.account_balance_wallet_outlined, children: [
      ...c.accounts.map((acc) {
        final isDef = acc.id == c.defaultAccountId;
        return ListTile(
          leading: CircleAvatar(backgroundColor: acc.color, child: const SizedBox.shrink()),
          title: Text(acc.name),
          subtitle: Text('Balance: ${acc.balance.toStringAsFixed(0)}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDef) Chip(label: const Text('Default'), visualDensity: VisualDensity.compact),
              IconButton(icon: const Icon(Icons.edit_outlined, size: 20), tooltip: 'Editar', onPressed: () => _editAccount(s, acc)),
              IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => s.removeAccount(acc.id)),
            ],
          ),
          onTap: () => s.setDefaultAccount(acc.id),
        );
      }),
      if (c.accounts.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Text('Sin billeteras. Agregá una.')),
      ListTile(
        leading: const Icon(Icons.add),
        title: const Text('Agregar billetera'),
        onTap: () => _addAccount(s),
      ),
    ]);
  }

  Widget _sectionRegistro(SettingsService s, AppSettings c) {
    return SectionCard(title: 'Registro', icon: Icons.edit_note_outlined, children: [
      SwitchListTile(
        secondary: const Icon(Icons.comment_outlined),
        title: const Text('Preguntar comentario'),
        subtitle: const Text('Al registrar, pregunta un comentario opcional.'),
        value: c.askForComment,
        onChanged: (v) => s.setAskForComment(v),
      ),
    ]);
  }

  Widget _sectionMoneda(SettingsService s, AppSettings c) {
    return SectionCard(title: 'Moneda', icon: Icons.currency_exchange, children: [
      ListTile(
        leading: const Icon(Icons.attach_money),
        title: const Text('Moneda principal'),
        trailing: DropdownButton<CurrencyInfo>(
          value: kCurrencies.firstWhere((cur) => cur.code == c.currencyCode, orElse: () => kDefaultCurrency),
          items: kCurrencies.map((cur) => DropdownMenuItem(value: cur, child: Text('${cur.code} - ${cur.name}'))).toList(),
          onChanged: (v) { if (v != null) s.setCurrencyCode(v.code); },
        ),
      ),
    ]);
  }

  Widget _sectionPresupuestos(SettingsService s, AppSettings c) {
    return SectionCard(title: 'Presupuestos', icon: Icons.savings_outlined, children: [
      ...c.budgets.map((b) => ListTile(
        leading: const Icon(Icons.pie_chart_outline),
        title: Text(b.categoryName),
        subtitle: Text('${formatBudgetPeriod(b.period)}: ${b.amount.toStringAsFixed(0)}'),
        trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => s.removeBudget(b.id)),
      )),
      if (c.budgets.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Text('Sin presupuestos.')),
      ListTile(
        leading: const Icon(Icons.add),
        title: const Text('Agregar presupuesto'),
        onTap: () => _addBudget(s),
      ),
    ]);
  }

  Widget _sectionAccesoRapido() {
    return SectionCard(title: 'Acceso rapido', icon: Icons.dashboard_customize_outlined, children: [
      ListTile(
        leading: const Icon(Icons.dashboard_customize),
        title: const Text('Agregar tiles al panel'),
        subtitle: const Text('Abre el asistente del sistema (Android 13+).'),
        onTap: () {
          const platform = MethodChannel('appgastos.dev/tile');
          platform.invokeMethod<bool>('requestAddTile');
        },
      ),
    ]);
  }

  Widget _sectionSeguridad(SettingsService s, AppSettings c) {
    return SectionCard(title: 'Seguridad y recordatorios', icon: Icons.security_outlined, children: [
      SwitchListTile(
        secondary: const Icon(Icons.fingerprint_outlined),
        title: const Text('Bloqueo biometrico'),
        subtitle: const Text('Requiere huella al abrir la app.'),
        value: c.biometricLock,
        onChanged: (v) => s.setBiometricLock(v),
      ),
      SwitchListTile(
        secondary: const Icon(Icons.notifications_outlined),
        title: const Text('Recordatorio de registro'),
        subtitle: Text('Notifica si no registras en ${c.reminderDays} dias.'),
        value: c.reminderEnabled,
        onChanged: (v) => s.setReminderEnabled(v),
      ),
      if (c.reminderEnabled)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('Cada ${c.reminderDays} dias', style: Theme.of(context).textTheme.bodyMedium),
              Expanded(
                child: Slider(
                  value: c.reminderDays.toDouble(),
                  min: 1, max: 14, divisions: 13,
                  label: '${c.reminderDays} dias',
                  onChanged: (v) => s.setReminderDays(v.round()),
                ),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _sectionWebhook(SettingsService s, AppSettings c) {
    return SectionCard(title: 'Webhook', icon: Icons.webhook, children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(controller: _webhookCtrl, decoration: const InputDecoration(labelText: 'URL del webhook', hintText: 'https://ejemplo.com/webhook', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)), keyboardType: TextInputType.url, autocorrect: false),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(children: [
          Expanded(child: FilledButton.tonal(onPressed: () => s.setWebhookUrl(_webhookCtrl.text.trim()), child: const Text('Guardar'))),
          const SizedBox(width: 8),
          IconButton.outlined(tooltip: 'Probar', icon: const Icon(Icons.send), onPressed: () {
            final url = _webhookCtrl.text.trim();
            if (url.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL vacia')));
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enviando prueba a $url')));
          }),
        ]),
      ),
      ListTile(
        leading: const Icon(Icons.code),
        title: const Text('Formato del payload'),
        subtitle: const Text('POST JSON con: event, id, amount, type, category, account, date, comment, app, version'),
        onTap: () => _showPayloadHelp(),
      ),
    ]);
  }

  Widget _sectionApi(SettingsService s, AppSettings c) {
    return SectionCard(title: 'API / Servidor', icon: Icons.cloud_outlined, children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(controller: _apiUrlCtrl, decoration: const InputDecoration(labelText: 'URL base del servidor', hintText: 'https://api.ejemplo.com/v1', border: OutlineInputBorder(), prefixIcon: Icon(Icons.dns)), keyboardType: TextInputType.url, autocorrect: false),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: TextField(controller: _apiTokenCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Token API', border: OutlineInputBorder(), prefixIcon: Icon(Icons.key)), autocorrect: false),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: FilledButton.tonal(onPressed: () { s.setApiBaseUrl(_apiUrlCtrl.text.trim()); s.setApiToken(_apiTokenCtrl.text.trim()); }, child: const Text('Guardar conexion')),
      ),
    ]);
  }

  Widget _sectionExportar() {
    return SectionCard(title: 'Exportar datos', icon: Icons.download_outlined, children: [
      ListTile(
        leading: const Icon(Icons.table_chart),
        title: const Text('Exportar a CSV'),
        subtitle: const Text('Descarga todos los registros en formato CSV.'),
        trailing: const Icon(Icons.share),
        onTap: () => _exportCSV(),
      ),
    ]);
  }

  Widget _sectionAcercaDe() {
    return SectionCard(title: 'Acerca de', icon: Icons.info_outline, children: [
      const ListTile(
        leading: Icon(Icons.savings_outlined),
        title: Text('AppGastos'),
        subtitle: Text('v1.2.0'),
      ),
    ]);
  }

  // ────────────────────────── DIALOGOS ──────────────────────────

  Future<void> _addAccount(SettingsService s) async {
    final nameCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');
    Color color = Colors.blue;
    if (!mounted) return;
    final picked = await ColorPickerWidget.pick(context, initialColor: color);
    if (picked != null && mounted) color = picked;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva billetera'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()), autofocus: true),
          const SizedBox(height: 12),
          TextField(controller: balCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Balance inicial', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) return;
            final bal = double.tryParse(balCtrl.text) ?? 0;
            s.addAccount(Account.create(name: name, color: color, balance: bal));
            Navigator.pop(ctx);
          }, child: const Text('Agregar')),
        ],
      ),
    );
  }

  Future<void> _editAccount(SettingsService s, Account acc) async {
    final nameCtrl = TextEditingController(text: acc.name);
    final balCtrl = TextEditingController(text: acc.balance.toStringAsFixed(0));
    Color color = acc.color;
    if (!mounted) return;
    final picked = await ColorPickerWidget.pick(context, initialColor: color);
    if (picked != null && mounted) color = picked;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar billetera'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: balCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Balance', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            final name = nameCtrl.text.trim();
            if (name.isEmpty) return;
            final bal = double.tryParse(balCtrl.text) ?? acc.balance;
            s.updateAccount(acc.id, name: name, color: color, balance: bal);
            Navigator.pop(ctx);
          }, child: const Text('Guardar')),
        ],
      ),
    );
  }

  Future<void> _addBudget(SettingsService s) async {
    final amtCtrl = TextEditingController();
    BudgetPeriod period = BudgetPeriod.monthly;
    String catName = ExpenseCategory.comida.name;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        title: const Text('Nuevo presupuesto'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: catName,
            decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
            items: ExpenseCategory.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.label))).toList(),
            onChanged: (v) { if (v != null) setSt(() => catName = v); },
          ),
          const SizedBox(height: 12),
          TextField(controller: amtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Limite', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money))),
          const SizedBox(height: 12),
          DropdownButtonFormField<BudgetPeriod>(
            value: period,
            decoration: const InputDecoration(labelText: 'Periodo', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: BudgetPeriod.weekly, child: Text('Semanal')),
              DropdownMenuItem(value: BudgetPeriod.monthly, child: Text('Mensual')),
            ],
            onChanged: (v) { if (v != null) setSt(() => period = v); },
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () {
            final amt = double.tryParse(amtCtrl.text) ?? 0;
            if (amt <= 0) return;
            s.addBudget(Budget.create(categoryName: catName, amount: amt, period: period));
            Navigator.pop(ctx);
          }, child: const Text('Crear')),
        ],
      )),
    );
  }

  Future<void> _exportCSV() async {
    final buf = StringBuffer('Fecha,Tipo,Categoria,Monto,Billetera,Comentario\n');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/appgastos_export.csv');
    await file.writeAsString(buf.toString());
    if (!mounted) return;
    await Share.shareXFiles([XFile(file.path)], text: 'Registros AppGastos');
  }

  void _showPayloadHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Formato del webhook'),
        content: const SingleChildScrollView(child: Text(
          'Cada vez que registras un gasto o ingreso se hace un POST con este JSON:\n\n'
          '{\n'
          '  "event": "expense.created",\n'
          '  "id": "...",\n'
          '  "amount": 15000.0,\n'
          '  "type": "gasto",\n'
          '  "category": "comida",\n'
          '  "account": { "id": "...", "name": "Efectivo", "color": 4283349034, "balance": 50000 },\n'
          '  "date": "2025-01-30T12:34:56.789Z",\n'
          '  "comment": "almuerzo",\n'
          '  "app": "AppGastos",\n'
          '  "version": 1\n'
          '}',
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
      ),
    );
  }

  String formatBudgetPeriod(BudgetPeriod p) => p == BudgetPeriod.weekly ? 'Semanal' : 'Mensual';
}
