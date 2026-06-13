import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cash_provider.dart';
import '../../providers/employees_provider.dart';
import '../../utils/formatters.dart';
import 'cash_history_screen.dart';
import 'recharge_sheet.dart';

/// Cuadre de caja del día: muestra los movimientos, el usuario cuenta el
/// efectivo y la app calcula cuánto debería haber, la diferencia y la ganancia.
class CashClosingScreen extends StatefulWidget {
  const CashClosingScreen({super.key});

  @override
  State<CashClosingScreen> createState() => _CashClosingScreenState();
}

class _CashClosingScreenState extends State<CashClosingScreen> {
  final _opening = TextEditingController();
  final _counted = TextEditingController();
  final _expenses = TextEditingController();
  final _note = TextEditingController();
  bool _openingSet = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestedOpening();
  }

  Future<void> _loadSuggestedOpening() async {
    final cash = context.read<CashProvider>();
    await cash.load();
    final suggested = await cash.suggestedOpeningBalance();
    if (!mounted) return;
    setState(() {
      if (!_openingSet) {
        _opening.text = suggested > 0 ? _money(suggested) : '';
      }
    });
  }

  @override
  void dispose() {
    _opening.dispose();
    _counted.dispose();
    _expenses.dispose();
    _note.dispose();
    super.dispose();
  }

  static String _money(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(0);

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  Future<void> _close() async {
    final cash = context.read<CashProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final counted = _parse(_counted);
    final opening = _parse(_opening);
    final expenses = _parse(_expenses);
    final expected = cash.expectedCash(opening, expenses);
    final diff = counted - expected;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cerrar la caja del día?'),
        content: Text(
          'Efectivo esperado: ${Formatters.cop(expected)}\n'
          'Efectivo contado: ${Formatters.cop(counted)}\n'
          '${diff == 0 ? 'La caja cuadra perfecto ✅' : diff > 0 ? 'Sobran ${Formatters.cop(diff)}' : 'Faltan ${Formatters.cop(-diff)}'}\n\n'
          'Ganancia del día: ${Formatters.cop(cash.todayProfit)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar caja'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await cash.saveClosing(
      openingBalance: opening,
      countedCash: counted,
      otherExpenses: expenses,
      note: _note.text.trim(),
    );
    _counted.clear();
    _expenses.clear();
    _note.clear();
    messenger.showSnackBar(
      const SnackBar(content: Text('Caja cerrada y guardada en el historial')),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cash = context.watch<CashProvider>();
    final employees = context.watch<EmployeesProvider>();
    final theme = Theme.of(context);
    final m = cash.today;

    final opening = _parse(_opening);
    final expenses = _parse(_expenses);
    final counted = _parse(_counted);
    final expected = cash.expectedCash(opening, expenses);
    final diff = counted - expected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuadre de caja'),
        actions: [
          IconButton(
            tooltip: 'Historial de cierres',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CashHistoryScreen()),
            ),
          ),
        ],
      ),
      body: cash.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- Recargas del día ---
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.smartphone_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Recargas de hoy',
                                  style: theme.textTheme.titleMedium),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => showRechargeSheet(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Recarga'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vendidas: ${Formatters.cop(m.rechargesAmount)}  ·  '
                          'Ganancia: ${Formatters.cop(m.rechargesProfit)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (cash.todayRecharges.isNotEmpty) ...[
                          const Divider(),
                          for (final r in cash.todayRecharges)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.smartphone, size: 20),
                              title: Text(Formatters.cop(r.amount)),
                              subtitle: Text(
                                '${Formatters.dateTime(r.date)}'
                                '${r.employeeId != null ? ' · ${employees.nameOf(r.employeeId)}' : ''}'
                                '${r.profit > 0 ? ' · gana ${Formatters.cop(r.profit)}' : ''}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                tooltip: 'Eliminar recarga',
                                onPressed: () => cash.deleteRecharge(r.id!),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // --- Movimientos automáticos del día ---
                Text('Movimientos del día', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        _MovementRow(
                          icon: Icons.payments_outlined,
                          label: 'Ventas de contado (+)',
                          value: m.salesCash,
                          color: Colors.green.shade700,
                        ),
                        _MovementRow(
                          icon: Icons.smartphone_outlined,
                          label: 'Recargas cobradas (+)',
                          value: m.rechargesAmount,
                          color: Colors.green.shade700,
                        ),
                        _MovementRow(
                          icon: Icons.south_west,
                          label: 'Abonos de fiados (+)',
                          value: m.creditPayments,
                          color: Colors.green.shade700,
                        ),
                        _MovementRow(
                          icon: Icons.receipt_long_outlined,
                          label: 'Facturas pagadas (−)',
                          value: m.debtsPaid,
                          color: theme.colorScheme.error,
                          negative: true,
                        ),
                        const Divider(height: 1),
                        _MovementRow(
                          icon: Icons.handshake_outlined,
                          label: 'Ventas fiadas (no entra a caja)',
                          value: m.salesCredit,
                          color: theme.colorScheme.outline,
                          muted: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- Datos que ingresa el usuario ---
                Text('Cuenta tu caja', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _opening,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Base inicial (con qué abriste)',
                    prefixText: r'$ ',
                  ),
                  onChanged: (_) => setState(() => _openingSet = true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _expenses,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Otros gastos / retiros (opcional)',
                    prefixText: r'$ ',
                    helperText: 'Dinero que sacaste de la caja por otras cosas',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _counted,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 20),
                  decoration: const InputDecoration(
                    labelText: 'Efectivo contado al cerrar',
                    prefixText: r'$ ',
                    helperText: 'Cuenta los billetes y monedas que hay ahora',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // --- Resultado ---
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _ResultRow(
                          label: 'Efectivo esperado',
                          value: Formatters.cop(expected),
                        ),
                        const SizedBox(height: 6),
                        _ResultRow(
                          label: 'Efectivo contado',
                          value: Formatters.cop(counted),
                        ),
                        const Divider(),
                        _ResultRow(
                          label: diff == 0
                              ? 'La caja cuadra'
                              : diff > 0
                                  ? 'Sobra'
                                  : 'Falta',
                          value: Formatters.cop(diff.abs()),
                          big: true,
                          color: diff == 0
                              ? Colors.green.shade800
                              : diff > 0
                                  ? Colors.blue.shade800
                                  : theme.colorScheme.error,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text('Ganancia del día', style: theme.textTheme.bodyMedium),
                              Text(
                                Formatters.cop(cash.todayProfit),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                'Productos ${Formatters.cop(m.productProfit)} + '
                                'recargas ${Formatters.cop(m.rechargesProfit)}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'Nota del cierre (opcional)',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: counted > 0 ? _close : null,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Cerrar caja del día'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tip: cierra la caja después de pagar las facturas del día y '
                  'de registrar las recargas, para que la cuenta salga exacta.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final Color color;
  final bool negative;
  final bool muted;

  const _MovementRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.negative = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 22),
      title: Text(label),
      trailing: Text(
        '${negative ? '−' : ''}${Formatters.cop(value)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: muted ? Theme.of(context).colorScheme.outline : color,
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool big;
  final Color? color;

  const _ResultRow({
    required this.label,
    required this.value,
    this.big = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = big
        ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)
        : theme.textTheme.bodyLarge?.copyWith(color: color);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
