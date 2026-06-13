import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cash_provider.dart';
import '../../widgets/employee_picker.dart';

/// Registra una recarga (plan de minutos/datos vendido a un celular).
void showRechargeSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _RechargeSheet(),
  );
}

class _RechargeSheet extends StatefulWidget {
  const _RechargeSheet();

  @override
  State<_RechargeSheet> createState() => _RechargeSheetState();
}

class _RechargeSheetState extends State<_RechargeSheet> {
  final _amount = TextEditingController();
  final _profit = TextEditingController();
  int? _employeeId;
  String _employeeName = '';

  @override
  void dispose() {
    _amount.dispose();
    _profit.dispose();
    super.dispose();
  }

  double _money(TextEditingController c) =>
      double.tryParse(c.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    final amount = _money(_amount);
    if (amount <= 0) return;
    final cash = context.read<CashProvider>();
    final navigator = Navigator.of(context);
    await cash.addRecharge(amount, _money(_profit), _employeeId);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registrar recarga', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'El valor recargado entra como efectivo a la caja, pero no es '
            'ganancia: solo la comisión cuenta como ganancia de la tienda.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(
              labelText: 'Valor de la recarga',
              prefixText: r'$ ',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _profit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Comisión / ganancia (opcional)',
              prefixText: r'$ ',
              helperText: 'Lo que te deja la recarga',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final e = await pickEmployee(context, title: '¿Quién hizo la recarga?');
              if (e != null) {
                setState(() {
                  _employeeId = e.id;
                  _employeeName = e.name;
                });
              }
            },
            icon: const Icon(Icons.person_outline),
            label: Text(_employeeName.isEmpty ? 'Responsable (opcional)' : _employeeName),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _money(_amount) > 0 ? _save : null,
              icon: const Icon(Icons.add),
              label: const Text('Guardar recarga'),
            ),
          ),
        ],
      ),
    );
  }
}
