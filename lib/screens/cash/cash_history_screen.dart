import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cash_closing.dart';
import '../../providers/cash_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';

/// Historial de los cierres de caja realizados.
class CashHistoryScreen extends StatelessWidget {
  const CashHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cash = context.watch<CashProvider>();
    final closings = cash.closings;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de cierres')),
      body: closings.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              message: 'Aún no has cerrado ninguna caja',
              hint: 'Cuando cierres la caja del día quedará registrada aquí',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: closings.length,
              itemBuilder: (context, i) => _ClosingTile(closing: closings[i]),
            ),
    );
  }
}

class _ClosingTile extends StatelessWidget {
  final CashClosing closing;

  const _ClosingTile({required this.closing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = closing;
    final diff = c.difference;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: diff == 0
              ? Colors.green.shade100
              : diff > 0
                  ? Colors.blue.shade100
                  : theme.colorScheme.errorContainer,
          child: Icon(
            diff == 0 ? Icons.check : Icons.account_balance_wallet_outlined,
            color: diff == 0
                ? Colors.green.shade700
                : diff > 0
                    ? Colors.blue.shade700
                    : theme.colorScheme.error,
          ),
        ),
        title: Text(Formatters.date(c.date),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'Ganancia ${Formatters.cop(c.totalProfit)} · '
          '${diff == 0 ? 'cuadró' : diff > 0 ? 'sobró ${Formatters.cop(diff)}' : 'faltó ${Formatters.cop(-diff)}'}',
        ),
        children: [
          _row('Base inicial', c.openingBalance),
          _row('Ventas de contado', c.salesCash),
          _row('Recargas vendidas', c.rechargesAmount),
          _row('Abonos de fiados', c.creditPayments),
          _row('Facturas pagadas', -c.debtsPaid),
          _row('Otros gastos', -c.otherExpenses),
          const Divider(),
          _row('Efectivo esperado', c.expectedCash, bold: true),
          _row('Efectivo contado', c.countedCash, bold: true),
          _row('Diferencia', c.difference, bold: true),
          const Divider(),
          _row('Ganancia productos', c.productProfit),
          _row('Ganancia recargas', c.rechargesProfit),
          _row('Ganancia total', c.totalProfit, bold: true),
          if (c.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Nota: ${c.note}', style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _row(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(
            Formatters.cop(value),
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
