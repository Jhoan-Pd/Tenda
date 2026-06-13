import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/customer.dart';
import '../../providers/cash_provider.dart';
import '../../providers/credit_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/sales_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/employee_picker.dart';
import 'voice_sale_screen.dart';

/// Punto de venta: busca productos, arma el carrito y cobra
/// (de contado o fiado). Al cobrar se descuenta el stock.
class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final sales = context.watch<SalesProvider>();
    final theme = Theme.of(context);

    final available = inventory
        .search(_query)
        .where((p) => !p.isOutOfStock)
        .toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar producto para vender...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _query = ''),
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 52,
                  width: 52,
                  child: IconButton.filled(
                    tooltip: 'Vender por voz',
                    icon: const Icon(Icons.mic),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VoiceSaleScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: available.isEmpty
                ? const EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    message: 'No hay productos disponibles',
                    hint: 'Agrega productos al inventario para empezar a vender',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: available.length,
                    itemBuilder: (context, i) {
                      final p = available[i];
                      final inCart = sales.cart
                          .where((c) => c.productId == p.id)
                          .fold(0.0, (sum, c) => sum + c.quantity);
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text('Stock: ${_qty(p.stock)}'),
                        leading: inCart > 0
                            ? CircleAvatar(
                                backgroundColor: theme.colorScheme.primary,
                                child: Text(
                                  _qty(inCart),
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : const CircleAvatar(child: Icon(Icons.add_shopping_cart, size: 18)),
                        trailing: Text(
                          Formatters.cop(p.price),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        onTap: () {
                          if (inCart >= p.stock) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('No hay más stock de ${p.name}'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                            return;
                          }
                          sales.addToCart(p);
                        },
                      );
                    },
                  ),
          ),
          if (sales.cart.isNotEmpty) _CartBar(sales: sales),
        ],
      ),
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}

class _CartBar extends StatelessWidget {
  final SalesProvider sales;

  const _CartBar({required this.sales});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemCount = sales.cart.fold(0.0, (sum, i) => sum + i.quantity);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _showCart(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_qty(itemCount)} artículo${itemCount == 1 ? '' : 's'} · Ver carrito',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      Formatters.cop(sales.cartTotal),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Vaciar carrito',
              icon: const Icon(Icons.remove_shopping_cart_outlined),
              onPressed: sales.clearCart,
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: () => _checkout(context),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Cobrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: sales,
        child: Consumer<SalesProvider>(
          builder: (context, sales, _) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Carrito', style: Theme.of(context).textTheme.titleLarge),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in sales.cart)
                        ListTile(
                          title: Text(item.productName),
                          subtitle: Text(
                            '${Formatters.cop(item.unitPrice)} c/u · ${Formatters.cop(item.subtotal)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () =>
                                    sales.updateQuantity(item, item.quantity - 1),
                              ),
                              Text(_qty(item.quantity)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () =>
                                    sales.updateQuantity(item, item.quantity + 1),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 16)),
                      Text(
                        Formatters.cop(sales.cartTotal),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkout(BuildContext context) async {
    final credit = context.read<CreditProvider>();
    final cash = context.read<CashProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final total = sales.cartTotal;

    final result = await showModalBottomSheet<_CheckoutResult>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Cobrar ${Formatters.cop(total)}',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
              title: const Text('De contado'),
              subtitle: const Text('El cliente paga ahora'),
              onTap: () => Navigator.pop(sheetContext, const _CheckoutResult()),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.handshake_outlined)),
              title: const Text('Fiado'),
              subtitle: const Text('Se anota a la cuenta de un cliente'),
              onTap: () async {
                final customer = await _pickCustomer(sheetContext, credit);
                if (customer == null || !sheetContext.mounted) return;
                final employee = await pickEmployee(
                  sheetContext,
                  title: '¿Quién fía a ${customer.name}?',
                );
                if (employee == null || !sheetContext.mounted) return;
                Navigator.pop(
                  sheetContext,
                  _CheckoutResult(customer: customer, employeeId: employee.id),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (result == null) return;
    await sales.checkout(creditCustomer: result.customer, employeeId: result.employeeId);
    await credit.load();
    await cash.load();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.customer == null
              ? 'Venta registrada: ${Formatters.cop(total)}'
              : 'Fiado anotado a ${result.customer!.name}: ${Formatters.cop(total)}',
        ),
      ),
    );
  }

  Future<Customer?> _pickCustomer(BuildContext context, CreditProvider credit) async {
    return showDialog<Customer>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('¿A quién se le fía?'),
        children: [
          for (final c in credit.customers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, c.customer),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(c.customer.name)),
                  if (c.balance > 0)
                    Text(
                      'Debe ${Formatters.cop(c.balance)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          SimpleDialogOption(
            onPressed: () async {
              final newCustomer = await _newCustomerDialog(dialogContext, credit);
              if (newCustomer != null && dialogContext.mounted) {
                Navigator.pop(dialogContext, newCustomer);
              }
            },
            child: Row(
              children: [
                Icon(Icons.person_add_outlined,
                    color: Theme.of(dialogContext).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Nuevo cliente',
                  style: TextStyle(color: Theme.of(dialogContext).colorScheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<Customer?> _newCustomerDialog(BuildContext context, CreditProvider credit) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    return showDialog<Customer>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final customer = await credit.addCustomer(name.text.trim(), phone.text.trim());
              if (dialogContext.mounted) Navigator.pop(dialogContext, customer);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}

class _CheckoutResult {
  final Customer? customer;
  final int? employeeId;
  const _CheckoutResult({this.customer, this.employeeId});
}
