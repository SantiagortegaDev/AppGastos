/// Selector de color con paleta + hex personalizado.
/// Devuelve un Color o null si se cancela.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';

class ColorPickerWidget extends StatefulWidget {
  final Color initialColor;
  const ColorPickerWidget({super.key, required this.initialColor});

  /// Muestra un diálogo y devuelve el color elegido (o null).
  static Future<Color?> pick(BuildContext context, {required Color initialColor}) {
    return showDialog<Color>(
      context: context,
      builder: (_) => ColorPickerWidget(initialColor: initialColor),
    );
  }

  @override
  State<ColorPickerWidget> createState() => _ColorPickerWidgetState();
}

class _ColorPickerWidgetState extends State<ColorPickerWidget> {
  late Color _selected;
  final _hexCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor;
    _hexCtrl.text = _colorToHex(_selected);
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  String _colorToHex(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  Color _hexToColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    } else if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Elegir color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Vista previa.
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: _selected,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
          ),
          const SizedBox(height: 16),
          // Paleta.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kColorPalettes.map((p) {
              final sel = _selected.value == p.color.value;
              return GestureDetector(
                onTap: () => setState(() {
                  _selected = p.color;
                  _hexCtrl.text = _colorToHex(p.color);
                }),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: p.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sel ? theme.colorScheme.onSurface : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: sel ? [BoxShadow(color: p.color.withValues(alpha: 0.4), blurRadius: 8)] : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Hex input.
          TextField(
            controller: _hexCtrl,
            keyboardType: TextInputType.text,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f#]'))],
            decoration: const InputDecoration(
              labelText: 'Color personalizado (HEX)',
              hintText: '#FF5733',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.colorize),
            ),
            onChanged: (v) {
              if (v.length >= 7) {
                try {
                  setState(() => _selected = _hexToColor(v));
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Elegir'),
        ),
      ],
    );
  }
}