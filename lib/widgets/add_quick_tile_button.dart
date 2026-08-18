/// Botón "Agregar acceso rápido" que invoca el intent nativo
/// `ACTION_QUICK_SETTINGS_ADD_TILE` (Android 13+).
///
/// En Android < 13, mostramos un diálogo con instrucciones manuales.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/tile_channel.dart';

class AddQuickTileButton extends StatelessWidget {
  final TileChannel tileChannel;
  const AddQuickTileButton({super.key, required this.tileChannel});

  Future<void> _tryAddTile(BuildContext context) async {
    const platform = MethodChannel('appgastos.dev/tile');
    try {
      // El lado Kotlin intenta lanzar ACTION_QUICK_SETTINGS_ADD_TILE.
      final bool? launched = await platform.invokeMethod<bool>('requestAddTile');
      if (launched != true && Platform.isAndroid) {
        // Fallback: instrucciones manuales.
        if (context.mounted) _showManualInstructions(context);
      }
    } on PlatformException {
      if (context.mounted) _showManualInstructions(context);
    }
  }

  void _showManualInstructions(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar el tile manualmente'),
        content: const Text(
          'Android no permite que las apps se agreguen solas al panel de '
          'ajustes rápidos por seguridad. Para hacerlo:\n\n'
          '1. Desliza el panel de ajustes rápidos desde arriba.\n'
          '2. Toca el ícono de lápiz ("Editar").\n'
          '3. Busca "AppGastos" en la lista.\n'
          '4. Arrástralo al panel principal.\n'
          '5. Toca "Listo".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () => _tryAddTile(context),
      icon: const Icon(Icons.dashboard_customize),
      label: const Text('Agregar acceso rápido'),
    );
  }
}
