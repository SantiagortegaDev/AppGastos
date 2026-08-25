/// Pantalla de estadísticas con gráficos.
library;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/expense.dart';
import '../models/currency.dart';
import '../services/expense_repository.dart';
import '../services/settings_service.dart';
import '../utils/formatters.dart';

enum _Period { day, week, month, year }

/// Widget de la pantalla de estadísticas.
/// Muestra gráficos de barras y de torta de los registros financieros.
///
/// Los parámetros [repository] y [settingsService] son obligatorios.
///
/// Ejemplo de uso:
/// ```dart
/// StatsScreen(repository: myRepo, settingsService: mySettings)
/// ```

class StatsScreen extends StatefulWidget {
  final ExpenseRepository repository;
  final SettingsService settingsService;
  const StatsScreen({super.key, required this.repository, required this.settingsService});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _Period _period = _Period.month;

  DateTime get _now => DateTime.now();
  DateTime get _from => switch (_period) {
    _Period.day => _now.subtract(const Duration(hours: 24)),
    _Period.week => _now.subtract(const Duration(days: 7)),
    _Period.month => DateTime(_now.year, _now.month - 1 < 1 ? 1 : _now.month - 1, _now.day),
    _Period.year => DateTime(_now.year - 1, _now.month, _now.day),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cur = widget.settingsService.settings.currency;
    final catTotals = widget.repository.categoryTotals(type: TransactionType.gasto, from: _from, to: _now);
    final sorted = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final daily = widget.repository.dailyTotals(from: _from, to: _now);
    final total = widget.repository.filter(from: _from, to: _now).fold<double>(0, (s, e) => e.type == TransactionType.gasto ? s + e.amount : s - e.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Selector de período.
          SegmentedButton<_Period>(
            segments: const [
              ButtonSegment(value: _Period.day, label: Text('Día')),
              ButtonSegment(value: _Period.week, label: Text('Semana')),
              ButtonSegment(value: _Period.month, label: Text('Mes')),
              ButtonSegment(value: _Period.year, label: Text('Año')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 16),
          // Balance del período.
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Balance del período', style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline)),
                  Text(formatCurrency(total, currency: cur),
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: total >= 0 ? Colors.green : cs.error)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Gráfico de torta.
          if (sorted.isNotEmpty) ...[
            Text('Gastos por categoría', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildPieChart(sorted, theme, cs, cur),
          ],
          const SizedBox(height: 24),
          // Gráfico de barras.
          if (daily.isNotEmpty) ...[
            Text('Actividad diaria', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildBarChart(daily, theme, cs, cur),
          ],
        ],
      ),
    );
  }

  Widget _buildPieChart(List<MapEntry<String, double>> sorted, ThemeData theme, ColorScheme cs, CurrencyInfo cur) {
    final total = sorted.fold<double>(0, (s, e) => s + e.value);
    return SizedBox(
      height: 240,
      child: PieChart(
        PieChartData(
          sections: sorted.asMap().entries.map((me) {
            final i = me.key;
            final cat = ExpenseCategory.fromName(me.value.key);
            final pct = total > 0 ? me.value.value / total : 0;
            return PieChartSectionData(
              value: me.value.value,
              color: cat.color,
              radius: 90,
              title: '${(pct * 100).toStringAsFixed(0)}%',
              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
          sectionsSpace: 2,
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<String, double> daily, ThemeData theme, ColorScheme cs, CurrencyInfo cur) {
    final entries = daily.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxVal = entries.fold<double>(0, (s, e) => e.value > s ? e.value : s);
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: entries.map((e) {
            return BarChartGroupData(
              x: entries.indexOf(e),
              barRods: [BarChartRodData(toY: e.value, color: cs.primary, borderRadius: BorderRadius.circular(6), width: 16)],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: entries.length <= 14,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                  final parts = entries[idx].key.split('-');
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${parts[2]}/${parts[1]}', style: const TextStyle(fontSize: 10)),
                  );
                },
                reservedSize: 28,
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
