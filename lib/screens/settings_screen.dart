/// Pantalla de ajustes.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;

import '../models/account.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../widgets/section_card.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  const SettingsScreen({super.key, required this.settingsService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _webhookCtrl;

  @override
  void initState() {
    super.initState();
    _webhookCtrl =
        TextEditingController(text: widget.settingsService.settings.webhookUrl);
  }

  @override
  void dispose() {
    _webhookCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settingsService;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final current = s.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('Ajustes')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ─────── Apariencia ───────
              SectionCard(
                title: 'Apariencia',
                icon: Icons.palette_outlined,
                children: [
                  ListTile(
                    leading: const Icon(Icons.brightness_6_outlined),
                    title: const Text('Tema'),
                    trailing: SegmentedButton<AppThemeMode>(
                      segments: const [
                        ButtonSegment(
                            value: AppThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined)),
                        ButtonSegment(
                            value: AppThemeMode.system,
                            icon: Icon(Icons.settings_brightness)),
                        ButtonSegment(
                            value: AppThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined)),
                      ],
                      selected: {current.themeMode},
                      onSelectionChanged: (sel) => s.setThemeMode(sel.first),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Color de la app',
                        style: theme.textTheme.titleSmall),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: kColorPalettes.map((p) {
                        final selected =
                            current.seedColor.value == p.color.value;
                        return GestureDetector(
                          onTap: () => s.setSeedColor(p.color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: p.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? theme.colorScheme.onSurface
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: [
                                if (selected)
                                  BoxShadow(
                                    color: p.color.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─────── Billeteras ───────
              SectionCard(
                title: 'Billeteras',
                icon: Icons.account_balance_wallet_outlined,
                children: [
                  ...current.accounts.map((acc) {
                    final isDefault = acc.id == current.defaultAccountId;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: acc.color,
                        child: const SizedBox.shrink(),
                      ),
                      title: Text(acc.name),
                      subtitle: Text(
                        'Balance: ${acc.balance.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isDefault)
                            Chip(
                              label: const Text('Default'),
                              visualDensity: VisualDensity.compact,
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Editar',
                            onPressed: () =>
                                _showEditAccountDialog(context, s, acc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => s.removeAccount(acc.id),
                          ),
                        ],
                      ),
                      onTap: () => s.setDefaultAccount(acc.id),
                    );
                  }),
                  if (current.accounts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No tenés billeteras. Agregá una abajo.'),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Agregar billetera'),
                    onTap: () => _showAddAccountDialog(context, s),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─────── Registro ───────
              SectionCard(
                title: 'Registro',
                icon: Icons.edit_note_outlined,
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.comment_outlined),
                    title: const Text('Preguntar comentario'),
                    subtitle: const Text(
                        'Al registrar, pregunta un comentario opcional.'),
                    value: current.askForComment,
                    onChanged: (v) => s.setAskForComment(v),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─────── Acceso rápido ───────
              SectionCard(
                title: 'Acceso rápido',
                icon: Icons.dashboard_customize_outlined,
                children: [
                  ListTile(
                    leading: const Icon(Icons.dashboard_customize),
                    title: const Text('Agregar tiles al panel'),
                    subtitle: const Text(
                        'Abre el asistente del sistema (Android 13+).'),
                    onTap: () {
                      const platform = MethodChannel('appgastos.dev/tile');
                      platform.invokeMethod<bool>('requestAddTile');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─────── Webhook ───────
              SectionCard(
                title: 'Webhook',
                icon: Icons.webhook,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _webhookCtrl,
                      decoration: const InputDecoration(
                        labelText: 'URL del webhook',
                        hintText: 'https://ejemplo.com/webhook',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: () =>
                                s.setWebhookUrl(_webhookCtrl.text.trim()),
                            child: const Text('Guardar webhook'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          tooltip: 'Probar webhook',
                          icon: const Icon(Icons.send),
                          onPressed: () {
                            final url = _webhookCtrl.text.trim();
                            if (url.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('URL vacía')),
                              );
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Enviando prueba a $url')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.code),
                    title: const Text('Formato del payload'),
                    subtitle: const Text(
                        'POST JSON con: event, id, amount, type, category, account, date, comment, app, version'),
                    onTap: () => _showPayloadHelp(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─────── Acerca de ───────
              SectionCard(
                title: 'Acerca de',
                icon: Icons.info_outline,
                children: [
                  ListTile(
                    title: const Text('AppGastos'),
                    subtitle: const Text('v1.1.0'),
                    leading: const Icon(Icons.savings_outlined),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Dialog: agregar billetera ──

  void _showAddAccountDialog(BuildContext context, SettingsService s) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    Color selectedColor = Colors.blue;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              title: const Text('Nueva billetera'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Balance inicial',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kColorPalettes.map((p) {
                      final sel = p.color.value == selectedColor.value;
                      return GestureDetector(
                        onTap: () => setSt(() => selectedColor = p.color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: p.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel ? Colors.black : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final bal =
                        double.tryParse(balanceCtrl.text) ?? 0;
                    s.addAccount(Account.create(
                        name: name,
                        color: selectedColor,
                        balance: bal));
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Dialog: editar billetera (nombre, color, balance) ──

  void _showEditAccountDialog(
      BuildContext context, SettingsService s, Account acc) {
    final nameCtrl = TextEditingController(text: acc.name);
    final balanceCtrl =
        TextEditingController(text: acc.balance.toStringAsFixed(0));
    Color selectedColor = acc.color;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return AlertDialog(
              title: const Text('Editar billetera'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Balance',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Color', style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kColorPalettes.map((p) {
                      final sel = p.color.value == selectedColor.value;
                      return GestureDetector(
                        onTap: () => setSt(() => selectedColor = p.color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: p.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel ? Colors.black : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final bal =
                        double.tryParse(balanceCtrl.text) ?? acc.balance;
                    s.updateAccount(
                      acc.id,
                      name: name,
                      color: selectedColor,
                      balance: bal,
                    );
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Dialog: ayuda payload webhook ──

  void _showPayloadHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Formato del webhook'),
        content: const SingleChildScrollView(
          child: Text(
            'Cada vez que registrás un gasto o ingreso, se hace un HTTP POST '
            'a la URL configurada con este JSON:\n\n'
            '{\n'
            '  "event": "expense.created",\n'
            '  "id": "1712345678-12345",\n'
            '  "amount": 15000.0,\n'
            '  "type": "gasto",\n'
            '  "category": "comida",\n'
            '  "account": {\n'
            '    "id": "acc-cash",\n'
            '    "name": "Efectivo",\n'
            '    "color": 4283349034,\n'
            '    "balance": 50000\n'
            '  },\n'
            '  "date": "2025-01-30T12:34:56.789Z",\n'
            '  "comment": "almuerzo con el equipo",\n'
            '  "app": "AppGastos",\n'
            '  "version": 1\n'
            '}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
