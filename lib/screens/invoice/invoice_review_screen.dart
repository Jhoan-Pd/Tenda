import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/invoice_item.dart';
import '../../providers/inventory_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/price_calculator.dart';

/// Revisión de los productos extraídos por la IA antes de pasarlos
/// al inventario. El usuario puede corregir nombre, cantidad, costo
/// y asignar el % de ganancia de cada producto.
class InvoiceReviewScreen extends StatefulWidget {
  final List<InvoiceItem> items;

  const InvoiceReviewScreen({super.key, required this.items});

  @override
  State<InvoiceReviewScreen> createState() => _InvoiceReviewScreenState();
}

class _InvoiceReviewScreenState extends State<InvoiceReviewScreen> {
  bool _importing = false;

  double get _invoiceTotal => widget.items
      .where((i) => i.selected)
      .fold(0.0, (sum, i) => sum + i.unitCost * i.quantity);

  int get _selectedCount => widget.items.where((i) => i.selected).length;

  Future<void> _import() async {
    if (_importing || _selectedCount == 0) return;
    setState(() => _importing = true);

    final inventory = context.read<InventoryProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final count = await inventory.importInvoiceItems(widget.items);

    messenger.showSnackBar(
      SnackBar(content: Text('$count producto${count == 1 ? '' : 's'} agregado${count == 1 ? '' : 's'} al inventario')),
    );
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Revisar productos')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'La IA detectó ${widget.items.length} producto${widget.items.length == 1 ? '' : 's'}. '
              'Toca uno para corregirlo y ajusta el % de ganancia.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: widget.items.length,
              itemBuilder: (context, i) {
                final item = widget.items[i];
                final price = PriceCalculator.sellingPrice(item.unitCost, item.marginPercent);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: Checkbox(
                      value: item.selected,
                      onChanged: (v) => setState(() => item.selected = v ?? true),
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      'x${_qty(item.quantity)} · Costo ${Formatters.cop(item.unitCost)} '
                      '· Gana ${_trim(item.marginPercent)}%',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Venta', style: theme.textTheme.bodySmall),
                        Text(
                          Formatters.cop(price),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _editItem(item),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total factura (seleccionados):'),
                      Text(
                        Formatters.cop(_invoiceTotal),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _selectedCount > 0 && !_importing ? _import : null,
                      icon: const Icon(Icons.playlist_add_check),
                      label: Text('Agregar $_selectedCount al inventario'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editItem(InvoiceItem item) async {
    final name = TextEditingController(text: item.name);
    final qty = TextEditingController(text: _qty(item.quantity));
    final cost = TextEditingController(text: _trim(item.unitCost));
    final margin = TextEditingController(text: _trim(item.marginPercent));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Corregir producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qty,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: cost,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Costo unit.',
                        prefixText: r'$ ',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: margin,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Ganancia',
                  suffixText: '%',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                item.name = name.text.trim().isEmpty ? item.name : name.text.trim();
                item.quantity = double.tryParse(qty.text.replaceAll(',', '.')) ?? item.quantity;
                item.unitCost = double.tryParse(cost.text.replaceAll(',', '.')) ?? item.unitCost;
                item.marginPercent =
                    double.tryParse(margin.text.replaceAll(',', '.')) ?? item.marginPercent;
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
