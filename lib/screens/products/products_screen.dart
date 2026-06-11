import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../invoice/invoice_scan_screen.dart';
import 'product_form_screen.dart';

/// Listado y búsqueda del inventario.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final products = inventory.search(_query);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
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
          Expanded(
            child: inventory.loading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        message: _query.isEmpty
                            ? 'Aún no tienes productos'
                            : 'No se encontró "$_query"',
                        hint: _query.isEmpty
                            ? 'Agrega productos con el botón + o escanea una factura con IA'
                            : null,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: products.length,
                        itemBuilder: (context, i) {
                          final p = products[i];
                          return _ProductTile(product: p, theme: theme);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'scan',
            tooltip: 'Escanear factura con IA',
            child: const Icon(Icons.document_scanner_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoiceScanScreen()),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add',
            tooltip: 'Agregar producto',
            child: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductFormScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final ThemeData theme;

  const _ProductTile({required this.product, required this.theme});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Costo ${Formatters.cop(p.cost)} · Gana ${_trim(p.marginPercent)}%'
          '${p.category != 'General' ? ' · ${p.category}' : ''}',
        ),
        leading: CircleAvatar(
          backgroundColor: p.isLowStock
              ? (p.isOutOfStock
                  ? theme.colorScheme.errorContainer
                  : Colors.orange.shade100)
              : theme.colorScheme.primaryContainer,
          child: Text(
            _qty(p.stock),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: p.isLowStock
                  ? (p.isOutOfStock ? theme.colorScheme.error : Colors.orange.shade900)
                  : theme.colorScheme.primary,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Formatters.cop(p.price),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: theme.colorScheme.primary,
              ),
            ),
            if (p.isLowStock)
              Text(
                p.isOutOfStock ? 'Agotado' : 'Poco stock',
                style: TextStyle(
                  fontSize: 11,
                  color: p.isOutOfStock ? theme.colorScheme.error : Colors.orange.shade800,
                ),
              ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)),
        ),
        onLongPress: () => _showActions(context),
      ),
    );
  }

  void _showActions(BuildContext context) {
    final inventory = context.read<InventoryProvider>();
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Agregar stock'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final qty = await _askQuantity(context);
                if (qty != null && qty > 0) {
                  await inventory.addStock(product, qty);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: Text('Eliminar', style: TextStyle(color: theme.colorScheme.error)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('¿Eliminar producto?'),
                    content: Text('Se eliminará "${product.name}" del inventario.'),
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
                  await inventory.deleteProduct(product.id!);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<double?> _askQuantity(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Agregar stock a ${product.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Cantidad a agregar'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
