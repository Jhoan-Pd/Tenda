import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/price_calculator.dart';

/// Formulario para crear o editar un producto.
///
/// El precio de venta se calcula automáticamente (costo + % de ganancia,
/// redondeado a \$50) pero el usuario puede ajustarlo manualmente.
class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _barcode;
  late final TextEditingController _cost;
  late final TextEditingController _margin;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _minStock;

  /// Si el usuario tocó el campo de precio, dejamos de recalcularlo.
  bool _priceEditedManually = false;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    final defaultMargin = context.read<SettingsProvider>().defaultMargin;
    _name = TextEditingController(text: p?.name ?? '');
    _category = TextEditingController(text: p?.category ?? 'General');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _cost = TextEditingController(text: p != null ? _trim(p.cost) : '');
    _margin = TextEditingController(text: _trim(p?.marginPercent ?? defaultMargin));
    _price = TextEditingController(text: p != null ? _trim(p.price) : '');
    _stock = TextEditingController(text: p != null ? _trim(p.stock) : '');
    _minStock = TextEditingController(text: _trim(p?.minStock ?? 5));
    _priceEditedManually = p != null &&
        p.price != PriceCalculator.sellingPrice(p.cost, p.marginPercent);
  }

  @override
  void dispose() {
    for (final c in [_name, _category, _barcode, _cost, _margin, _price, _stock, _minStock]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  double get _costValue => double.tryParse(_cost.text.replaceAll(',', '.')) ?? 0;
  double get _marginValue => double.tryParse(_margin.text.replaceAll(',', '.')) ?? 0;

  void _recalculatePrice() {
    if (_priceEditedManually) return;
    final price = PriceCalculator.sellingPrice(_costValue, _marginValue);
    _price.text = price > 0 ? _trim(price) : '';
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    final inventory = context.read<InventoryProvider>();
    final navigator = Navigator.of(context);
    final price = double.tryParse(_price.text.replaceAll(',', '.')) ??
        PriceCalculator.sellingPrice(_costValue, _marginValue);

    final product = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      category: _category.text.trim().isEmpty ? 'General' : _category.text.trim(),
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      cost: _costValue,
      marginPercent: _marginValue,
      price: price,
      stock: double.tryParse(_stock.text.replaceAll(',', '.')) ?? 0,
      minStock: double.tryParse(_minStock.text.replaceAll(',', '.')) ?? 5,
      createdAt: widget.product?.createdAt,
    );

    if (_isEditing) {
      await inventory.updateProduct(product);
    } else {
      await inventory.addProduct(product);
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestedPrice = PriceCalculator.sellingPrice(_costValue, _marginValue);
    final profit = (double.tryParse(_price.text.replaceAll(',', '.')) ?? suggestedPrice) - _costValue;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar producto' : 'Nuevo producto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre del producto *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe el nombre' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _category,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _barcode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Código de barras'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Precio', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Costo unitario *',
                      prefixText: r'$ ',
                      helperText: 'Lo que pagas al proveedor',
                    ),
                    validator: (v) {
                      final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                      if (value == null || value <= 0) return 'Costo inválido';
                      return null;
                    },
                    onChanged: (_) => _recalculatePrice(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _margin,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Ganancia *',
                      suffixText: '%',
                      helperText: 'Margen de este producto',
                    ),
                    validator: (v) {
                      final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                      if (value == null || value < 0) return 'Margen inválido';
                      return null;
                    },
                    onChanged: (_) => _recalculatePrice(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Precio de venta *',
                prefixText: r'$ ',
                helperText: 'Sugerido: ${Formatters.cop(suggestedPrice)} (redondeado a \$50)',
                suffixIcon: _priceEditedManually
                    ? IconButton(
                        tooltip: 'Volver al precio sugerido',
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          _priceEditedManually = false;
                          _recalculatePrice();
                        },
                      )
                    : null,
              ),
              validator: (v) {
                final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (value == null || value <= 0) return 'Precio inválido';
                return null;
              },
              onChanged: (_) {
                _priceEditedManually = true;
                setState(() {});
              },
            ),
            if (_costValue > 0 && profit != 0) ...[
              const SizedBox(height: 8),
              Text(
                'Ganancia por unidad: ${Formatters.cop(profit)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: profit > 0 ? Colors.green.shade700 : theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text('Inventario', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Stock actual'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minStock,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Stock mínimo',
                      helperText: 'Alerta al llegar aquí',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'Guardar cambios' : 'Agregar producto'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
          ],
        ),
      ),
    );
  }
}
