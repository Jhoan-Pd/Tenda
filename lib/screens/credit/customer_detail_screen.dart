import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/customer.dart';
import '../../providers/credit_provider.dart';
import '../../providers/employees_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/employee_picker.dart';

/// Cuenta de un cliente: saldo, historial de fiados y abonos.
class CustomerDetailScreen extends StatelessWidget {
  final int customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    final credit = context.watch<CreditProvider>();
    final theme = Theme.of(context);

    final matches = credit.customers.where((c) => c.customer.id == customerId);
    if (matches.isEmpty) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final c = matches.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(c.customer.name),
        actions: [
          IconButton(
            tooltip: 'Eliminar cliente',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, c.customer),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: c.balance > 0
                ? theme.colorScheme.errorContainer
                : Colors.green.shade50,
            child: Column(
              children: [
                Text(
                  c.balance > 0 ? 'Debe' : 'Al día',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  Formatters.cop(c.balance > 0 ? c.balance : 0),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: c.balance > 0
                        ? theme.colorScheme.error
                        : Colors.green.shade700,
                  ),
                ),
                if (c.customer.phone.isNotEmpty)
                  Text(c.customer.phone, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addEntry(context, c.customer, isPayment: false),
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('Anotar fiado'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        c.balance > 0 ? () => _addEntry(context, c.customer, isPayment: true) : null,
                    icon: const Icon(Icons.attach_money),
                    label: const Text('Recibir abono'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CreditEntry>>(
              future: credit.entriesOf(c.customer),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = snapshot.data!;
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      'Sin movimientos todavía',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final responsible = context.read<EmployeesProvider>().nameOf(e.employeeId);
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        e.isPayment ? Icons.south_west : Icons.north_east,
                        color: e.isPayment ? Colors.green : theme.colorScheme.error,
                      ),
                      title: Text(
                        '${e.isPayment ? 'Abono' : 'Fiado'}'
                        '${responsible.isNotEmpty ? ' · $responsible' : ''}',
                      ),
                      subtitle: Text(
                        e.description.isNotEmpty
                            ? '${e.description}\n${Formatters.dateTime(e.date)}'
                            : Formatters.dateTime(e.date),
                      ),
                      isThreeLine: e.description.isNotEmpty,
                      trailing: Text(
                        '${e.isPayment ? '-' : '+'}${Formatters.cop(e.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: e.isPayment ? Colors.green : theme.colorScheme.error,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addEntry(BuildContext context, Customer customer,
      {required bool isPayment}) async {
    final credit = context.read<CreditProvider>();

    // Primero se elige el responsable (Ferney, Ana, ...).
    final employee = await pickEmployee(
      context,
      title: isPayment ? '¿Quién recibe el abono?' : '¿Quién fía a ${customer.name}?',
    );
    if (employee == null || !context.mounted) return;

    final amount = TextEditingController();
    final description = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isPayment ? 'Recibir abono' : 'Anotar fiado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Responsable: ${employee.name}',
                  style: Theme.of(dialogContext).textTheme.bodySmall),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor', prefixText: r'$ '),
            ),
            if (!isPayment) ...[
              const SizedBox(height: 12),
              TextField(
                controller: description,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Ej: Pan y leche',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(
                  amount.text.replaceAll('.', '').replaceAll(',', '.'));
              if (value == null || value <= 0) return;
              if (isPayment) {
                await credit.addPayment(customer, value, employeeId: employee.id);
              } else {
                await credit.addCharge(customer, value, description.text.trim(),
                    employeeId: employee.id);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Customer customer) async {
    final credit = context.read<CreditProvider>();
    final navigator = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar cliente?'),
        content: Text(
          'Se eliminará a ${customer.name} y todo su historial de fiados.',
        ),
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
      await credit.deleteCustomer(customer.id!);
      navigator.pop();
    }
  }
}
