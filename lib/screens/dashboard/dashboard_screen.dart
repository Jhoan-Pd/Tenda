import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cash_provider.dart';
import '../../providers/credit_provider.dart';
import '../../providers/debts_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/sales_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/summary_card.dart';
import '../alerts/alerts_screen.dart';
import '../cash/cash_closing_screen.dart';
import '../cash/recharge_sheet.dart';
import '../invoice/invoice_scan_screen.dart';
import '../products/product_form_screen.dart';
import '../sales/sales_history_screen.dart';
import 'price_calculator_sheet.dart';

/// Resumen general de la tienda y accesos rápidos.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final debts = context.watch<DebtsProvider>();
    final sales = context.watch<SalesProvider>();
    final credit = context.watch<CreditProvider>();
    final cash = context.watch<CashProvider>();
    final theme = Theme.of(context);

    final alerts =
        inventory.lowStockProducts.length + debts.dueSoonOrOverdue.length;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          inventory.load(),
          debts.load(),
          sales.loadToday(),
          credit.load(),
          cash.load(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (alerts > 0)
            Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(Icons.warning_amber_rounded,
                    color: theme.colorScheme.onErrorContainer),
                title: Text(
                  'Tienes $alerts alerta${alerts == 1 ? '' : 's'} pendiente${alerts == 1 ? '' : 's'}',
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
                subtitle: Text(
                  'Productos agotándose o deudas por vencer',
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                ),
              ),
            ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.5,
            children: [
              SummaryCard(
                title: 'Ventas de hoy',
                value: Formatters.cop(sales.todayTotal),
                subtitle: '${sales.todayCount} venta${sales.todayCount == 1 ? '' : 's'}',
                icon: Icons.trending_up,
                color: Colors.green.shade700,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
                ),
              ),
              SummaryCard(
                title: 'Inventario (costo)',
                value: Formatters.cop(inventory.totalInventoryValue),
                subtitle: '${inventory.products.length} productos',
                icon: Icons.inventory_2_outlined,
                color: Colors.blue.shade700,
              ),
              SummaryCard(
                title: 'Deudas pendientes',
                value: Formatters.cop(debts.totalOwed),
                subtitle: debts.totalOwed > 0
                    ? 'Ahorra ${Formatters.cop(debts.totalDailySaving)}/día'
                    : 'Sin deudas 🎉',
                icon: Icons.receipt_long_outlined,
                color: Colors.orange.shade800,
              ),
              SummaryCard(
                title: 'Fiados por cobrar',
                value: Formatters.cop(credit.totalCredit),
                subtitle: '${credit.debtors.length} cliente${credit.debtors.length == 1 ? '' : 's'}',
                icon: Icons.people_outline,
                color: Colors.purple.shade700,
              ),
              SummaryCard(
                title: 'Ganancia de hoy',
                value: Formatters.cop(cash.todayProfit),
                subtitle: 'Toca para cuadrar caja',
                icon: Icons.savings_outlined,
                color: Colors.teal.shade700,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CashClosingScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Acciones rápidas', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.document_scanner_outlined)),
                  title: const Text('Escanear factura con IA'),
                  subtitle: const Text('Toma la foto y la IA extrae productos y precios'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InvoiceScanScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.calculate_outlined)),
                  title: const Text('Calculadora de precios'),
                  subtitle: const Text('Costo + % de ganancia = precio de venta'),
                  onTap: () => showPriceCalculatorSheet(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.add_box_outlined)),
                  title: const Text('Agregar producto manual'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProductFormScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.point_of_sale_outlined)),
                  title: const Text('Cuadre de caja'),
                  subtitle: const Text('Cierra el día: cuenta el efectivo y mira la ganancia'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CashClosingScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.smartphone_outlined)),
                  title: const Text('Registrar recarga'),
                  subtitle: const Text('Planes de minutos o datos vendidos'),
                  onTap: () => showRechargeSheet(context),
                ),
              ],
            ),
          ),
          if (inventory.lowStockProducts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Productos agotándose', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final p in inventory.lowStockProducts.take(5))
                    ListTile(
                      dense: true,
                      leading: Icon(
                        p.isOutOfStock ? Icons.error_outline : Icons.warning_amber_rounded,
                        color: p.isOutOfStock ? theme.colorScheme.error : Colors.orange,
                      ),
                      title: Text(p.name),
                      trailing: Text(
                        p.isOutOfStock ? 'Agotado' : 'Quedan ${_qty(p.stock)}',
                        style: TextStyle(
                          color: p.isOutOfStock ? theme.colorScheme.error : Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
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
