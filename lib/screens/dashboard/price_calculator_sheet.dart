import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/price_calculator.dart';

/// Calculadora rápida: ingresa costo y % de ganancia y muestra el precio
/// de venta sugerido (redondeado a múltiplos de \$50).
void showPriceCalculatorSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _PriceCalculatorSheet(),
  );
}

class _PriceCalculatorSheet extends StatefulWidget {
  const _PriceCalculatorSheet();

  @override
  State<_PriceCalculatorSheet> createState() => _PriceCalculatorSheetState();
}

class _PriceCalculatorSheetState extends State<_PriceCalculatorSheet> {
  final _costController = TextEditingController();
  late final TextEditingController _marginController;

  @override
  void initState() {
    super.initState();
    final defaultMargin = context.read<SettingsProvider>().defaultMargin;
    _marginController = TextEditingController(text: _trimZeros(defaultMargin));
  }

  @override
  void dispose() {
    _costController.dispose();
    _marginController.dispose();
    super.dispose();
  }

  static String _trimZeros(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cost = Formatters.parseMoney(_costController.text) ?? 0;
    final margin = double.tryParse(_marginController.text.replaceAll(',', '.')) ?? 0;
    final price = PriceCalculator.sellingPrice(cost, margin);
    final profit = price - cost;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calculadora de precios', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _costController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Costo unitario',
                    prefixText: r'$ ',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _marginController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Ganancia',
                    suffixText: '%',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Precio de venta', style: theme.textTheme.bodySmall),
                      Text(
                        Formatters.cop(price),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Ganancia', style: theme.textTheme.bodySmall),
                      Text(
                        Formatters.cop(profit),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'El precio se redondea hacia arriba al múltiplo de \$50 más cercano.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
