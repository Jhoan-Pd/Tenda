import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/debts_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../debts/debt_detail_screen.dart';
import '../products/product_form_screen.dart';

/// Centro de alertas: productos agotándose y deudas por vencer.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final debts = context.watch<DebtsProvider>();
    final theme = Theme.of(context);

    final lowStock = inventory.lowStockProducts;
    final dueDebts = debts.dueSoonOrOverdue;

    return Scaffold(
      appBar: AppBar(title: const Text('Alertas')),
      body: (lowStock.isEmpty && dueDebts.isEmpty)
          ? const EmptyState(
              icon: Icons.check_circle_outline,
              message: 'Todo en orden',
              hint: 'No hay productos agotándose ni deudas por vencer',
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (dueDebts.isNotEmpty) ...[
                  Text('Deudas por vencer', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final d in dueDebts)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          d.isOverdue ? Icons.error_outline : Icons.schedule,
                          color: d.isOverdue ? theme.colorScheme.error : Colors.orange,
                        ),
                        title: Text(d.debt.supplier),
                        subtitle: Text(
                          d.isOverdue
                              ? 'Vencida hace ${-d.daysUntilDue} día${-d.daysUntilDue == 1 ? '' : 's'}'
                              : d.daysUntilDue == 0
                                  ? '¡Vence hoy!'
                                  : 'Vence en ${d.daysUntilDue} día${d.daysUntilDue == 1 ? '' : 's'} '
                                      '· Ahorra ${Formatters.cop(d.dailySaving)}/día',
                        ),
                        trailing: Text(
                          Formatters.cop(d.remaining),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: d.isOverdue ? theme.colorScheme.error : Colors.orange.shade800,
                          ),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DebtDetailScreen(debtId: d.debt.id!),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                if (lowStock.isNotEmpty) ...[
                  Text('Productos agotándose', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final p in lowStock)
                    Card(
                      child: ListTile(
                        leading: Icon(
                          p.isOutOfStock ? Icons.error_outline : Icons.warning_amber_rounded,
                          color: p.isOutOfStock ? theme.colorScheme.error : Colors.orange,
                        ),
                        title: Text(p.name),
                        subtitle: Text(
                          p.isOutOfStock
                              ? 'Sin unidades — pide más a tu proveedor'
                              : 'Quedan ${_qty(p.stock)} (mínimo ${_qty(p.minStock)})',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductFormScreen(product: p),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}
