import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/debt.dart';
import '../../providers/debts_provider.dart';
import '../../utils/formatters.dart';

/// Detalle de una deuda: plan de ahorro diario/semanal, abonos
/// realizados y opciones para abonar o marcar como pagada.
class DebtDetailScreen extends StatelessWidget {
  final int debtId;

  const DebtDetailScreen({super.key, required this.debtId});

  @override
  Widget build(BuildContext context) {
    final debtsProvider = context.watch<DebtsProvider>();
    final theme = Theme.of(context);

    final matches = debtsProvider.debts.where((d) => d.debt.id == debtId);
    if (matches.isEmpty) {
      // La deuda fue eliminada mientras la pantalla estaba abierta.
      return const Scaffold(body: SizedBox.shrink());
    }
    final d = matches.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(d.debt.supplier),
        actions: [
          IconButton(
            tooltip: 'Eliminar deuda',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, d),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (d.debt.description.isNotEmpty) ...[
            Text(d.debt.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
          ],
          Card(
            color: d.isSettled
                ? Colors.green.shade50
                : theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Saldo pendiente', style: theme.textTheme.bodySmall),
                          Text(
                            Formatters.cop(d.remaining),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: d.isSettled ? Colors.green.shade700 : null,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Total factura', style: theme.textTheme.bodySmall),
                          Text(
                            Formatters.cop(d.debt.totalAmount),
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: d.debt.totalAmount > 0
                        ? (d.totalPaid / d.debt.totalAmount).clamp(0.0, 1.0)
                        : 0,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Abonado: ${Formatters.cop(d.totalPaid)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!d.isSettled) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          d.isOverdue ? Icons.warning_amber_rounded : Icons.savings_outlined,
                          color: d.isOverdue ? theme.colorScheme.error : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text('Plan de ahorro', style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (d.isOverdue)
                      Text(
                        'Esta deuda venció hace ${-d.daysUntilDue} día${-d.daysUntilDue == 1 ? '' : 's'}. '
                        'Debes ${Formatters.cop(d.remaining)} ya.',
                        style: TextStyle(color: theme.colorScheme.error),
                      )
                    else ...[
                      Text(
                        'Vence el ${Formatters.date(d.debt.dueDate)} '
                        '(en ${d.daysUntilDue} día${d.daysUntilDue == 1 ? '' : 's'}).',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _SavingBox(
                              label: 'Cada día guarda',
                              value: Formatters.cop(d.dailySaving),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SavingBox(
                              label: 'Cada semana guarda',
                              value: Formatters.cop(d.weeklySaving),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addPayment(context, d),
                    icon: const Icon(Icons.add_card_outlined),
                    label: const Text('Abonar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _markPaid(context, d),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Pagar todo'),
                  ),
                ),
              ],
            ),
          ],
          if (d.payments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Abonos', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Card(
              child: Column(
                children: [
                  for (final p in d.payments)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.check, color: Colors.green),
                      title: Text(Formatters.cop(p.amount)),
                      trailing: Text(Formatters.dateTime(p.date)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addPayment(BuildContext context, DebtWithPayments d) async {
    final controller = TextEditingController();
    final debts = context.read<DebtsProvider>();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar abono'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Valor del abono',
            prefixText: r'$ ',
            helperText: 'Saldo pendiente: ${Formatters.cop(d.remaining)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.replaceAll('.', '').replaceAll(',', '.')),
            ),
            child: const Text('Abonar'),
          ),
        ],
      ),
    );
    if (amount != null && amount > 0) {
      await debts.addPayment(d, amount);
    }
  }

  Future<void> _markPaid(BuildContext context, DebtWithPayments d) async {
    final debts = context.read<DebtsProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Pagar toda la deuda?'),
        content: Text(
          'Se registrará el pago del saldo de ${Formatters.cop(d.remaining)} '
          'a ${d.debt.supplier}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar pago'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await debts.markPaid(d);
    }
  }

  Future<void> _confirmDelete(BuildContext context, DebtWithPayments d) async {
    final debts = context.read<DebtsProvider>();
    final navigator = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar deuda?'),
        content: Text('Se eliminará la deuda con ${d.debt.supplier} y sus abonos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await debts.deleteDebt(d.debt.id!);
      navigator.pop();
    }
  }
}

class _SavingBox extends StatelessWidget {
  final String label;
  final String value;

  const _SavingBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
