import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/credit_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import 'customer_detail_screen.dart';

/// Clientes con cuenta de fiado y cuánto debe cada uno.
class CreditScreen extends StatelessWidget {
  const CreditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final credit = context.watch<CreditProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: credit.loading
          ? const Center(child: CircularProgressIndicator())
          : credit.customers.isEmpty
              ? const EmptyState(
                  icon: Icons.people_outline,
                  message: 'No tienes clientes con fiado',
                  hint: 'Agrega clientes con el botón + o desde la pantalla de venta',
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 88, top: 8),
                  children: [
                    if (credit.totalCredit > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          color: theme.colorScheme.tertiaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total fiado por cobrar', style: theme.textTheme.bodySmall),
                                Text(
                                  Formatters.cop(credit.totalCredit),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    for (final c in credit.customers)
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              c.customer.name.isNotEmpty
                                  ? c.customer.name[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(c.customer.name),
                          subtitle: c.customer.phone.isNotEmpty
                              ? Text(c.customer.phone)
                              : null,
                          trailing: Text(
                            c.balance > 0 ? 'Debe ${Formatters.cop(c.balance)}' : 'Al día',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: c.balance > 0
                                  ? theme.colorScheme.error
                                  : Colors.green.shade700,
                            ),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CustomerDetailScreen(customerId: c.customer.id!),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo cliente',
        child: const Icon(Icons.person_add_outlined),
        onPressed: () => _addCustomer(context),
      ),
    );
  }

  Future<void> _addCustomer(BuildContext context) async {
    final credit = context.read<CreditProvider>();
    final name = TextEditingController();
    final phone = TextEditingController();

    await showDialog<void>(
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
              await credit.addCustomer(name.text.trim(), phone.text.trim());
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
