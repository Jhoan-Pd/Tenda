import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/debt.dart';
import '../../providers/debts_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import 'debt_detail_screen.dart';
import 'debt_form_screen.dart';

/// Facturas pendientes de pago a proveedores, con plan de ahorro.
class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final debtsProvider = context.watch<DebtsProvider>();
    final theme = Theme.of(context);
    final pending = debtsProvider.pending;
    final settled = debtsProvider.settled;

    return Scaffold(
      body: debtsProvider.loading
          ? const Center(child: CircularProgressIndicator())
          : (pending.isEmpty && settled.isEmpty)
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: 'No tienes facturas pendientes',
                  hint: 'Agenda las facturas de tus proveedores con el botón + '
                      'y te diremos cuánto ahorrar para pagarlas a tiempo',
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 88, top: 8),
                  children: [
                    if (pending.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          color: theme.colorScheme.primaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total por pagar', style: theme.textTheme.bodySmall),
                                Text(
                                  Formatters.cop(debtsProvider.totalOwed),
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Para cumplir todas las fechas, ahorra '
                                  '${Formatters.cop(debtsProvider.totalDailySaving)} cada día.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final d in pending) _DebtTile(debt: d),
                    ],
                    if (settled.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text('Pagadas', style: theme.textTheme.titleSmall),
                      ),
                      for (final d in settled) _DebtTile(debt: d),
                    ],
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Agendar factura por pagar',
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DebtFormScreen()),
        ),
      ),
    );
  }
}

class _DebtTile extends StatelessWidget {
  final DebtWithPayments debt;

  const _DebtTile({required this.debt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = debt;

    Color statusColor;
    String statusText;
    if (d.isSettled) {
      statusColor = Colors.green.shade700;
      statusText = 'Pagada';
    } else if (d.isOverdue) {
      statusColor = theme.colorScheme.error;
      statusText = 'Vencida hace ${-d.daysUntilDue} día${-d.daysUntilDue == 1 ? '' : 's'}';
    } else if (d.daysUntilDue == 0) {
      statusColor = theme.colorScheme.error;
      statusText = '¡Vence hoy!';
    } else {
      statusColor = d.isDueSoon ? Colors.orange.shade800 : theme.colorScheme.outline;
      statusText = 'Vence en ${d.daysUntilDue} día${d.daysUntilDue == 1 ? '' : 's'}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: d.isSettled
              ? Colors.green.shade100
              : (d.isOverdue || d.isDueSoon)
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            d.isSettled ? Icons.check : Icons.receipt_long_outlined,
            color: d.isSettled ? Colors.green.shade700 : statusColor,
            size: 20,
          ),
        ),
        title: Text(d.debt.supplier, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${Formatters.date(d.debt.dueDate)} · $statusText'
          '${d.totalPaid > 0 && !d.isSettled ? '\nAbonado ${Formatters.cop(d.totalPaid)}' : ''}',
        ),
        isThreeLine: d.totalPaid > 0 && !d.isSettled,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Formatters.cop(d.isSettled ? d.debt.totalAmount : d.remaining),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: d.isSettled ? Colors.green.shade700 : statusColor,
              ),
            ),
            if (!d.isSettled)
              Text(
                '${Formatters.cop(d.dailySaving)}/día',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DebtDetailScreen(debtId: d.debt.id!)),
        ),
      ),
    );
  }
}
