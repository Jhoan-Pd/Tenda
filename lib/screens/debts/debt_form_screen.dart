import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/debt.dart';
import '../../providers/debts_provider.dart';
import '../../utils/formatters.dart';

/// Agendar una factura por pagar (deuda con proveedor).
class DebtFormScreen extends StatefulWidget {
  const DebtFormScreen({super.key});

  @override
  State<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends State<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplier = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void dispose() {
    _supplier.dispose();
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  double get _amountValue =>
      double.tryParse(_amount.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  int get _days {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(_dueDate.year, _dueDate.month, _dueDate.day);
    return due.difference(today).inDays;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Fecha límite de pago',
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    final debts = context.read<DebtsProvider>();
    final navigator = Navigator.of(context);

    await debts.addDebt(Debt(
      supplier: _supplier.text.trim(),
      description: _description.text.trim(),
      totalAmount: _amountValue,
      dueDate: _dueDate,
    ));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = _amountValue;
    final days = _days;
    final daily = days > 0 ? amount / days : amount;
    final weekly = days > 7 ? amount / (days / 7) : amount;

    return Scaffold(
      appBar: AppBar(title: const Text('Agendar factura por pagar')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _supplier,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Proveedor *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Escribe el proveedor' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Ej: Factura #123 gaseosas',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor total *',
                prefixText: r'$ ',
              ),
              validator: (_) => _amountValue <= 0 ? 'Valor inválido' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(4),
              ),
              leading: const Icon(Icons.event_outlined),
              title: const Text('Fecha límite de pago'),
              subtitle: Text(
                '${Formatters.date(_dueDate)} (en $days día${days == 1 ? '' : 's'})',
              ),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
            if (amount > 0) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plan de ahorro sugerido', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      _PlanRow(
                        icon: Icons.today_outlined,
                        label: 'Ahorro diario',
                        value: Formatters.cop(daily),
                      ),
                      const SizedBox(height: 4),
                      _PlanRow(
                        icon: Icons.date_range_outlined,
                        label: 'Ahorro semanal',
                        value: Formatters.cop(weekly),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Agendar deuda'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PlanRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
