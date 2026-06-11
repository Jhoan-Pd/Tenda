import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sale.dart';
import '../../providers/sales_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';

/// Historial de ventas con filtro por rango de fechas.
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  late DateTime _from;
  late DateTime _to;
  List<Sale> _sales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    _to = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sales = await context.read<SalesProvider>().salesBetween(_from, _to);
    if (!mounted) return;
    setState(() {
      _sales = sales;
      _loading = false;
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _from,
        end: _to.subtract(const Duration(days: 1)),
      ),
    );
    if (picked == null) return;
    setState(() {
      _from = picked.start;
      _to = DateTime(picked.end.year, picked.end.month, picked.end.day)
          .add(const Duration(days: 1));
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _sales.fold(0.0, (sum, s) => sum + s.total);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de ventas'),
        actions: [
          IconButton(
            tooltip: 'Cambiar fechas',
            icon: const Icon(Icons.date_range),
            onPressed: _pickRange,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Formatters.date(_from)} — ${Formatters.date(_to.subtract(const Duration(days: 1)))}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${_sales.length} venta${_sales.length == 1 ? '' : 's'} · ${Formatters.cop(total)}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _sales.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_outlined,
                        message: 'No hay ventas en este período',
                      )
                    : ListView.builder(
                        itemCount: _sales.length,
                        itemBuilder: (context, i) => _SaleTile(sale: _sales[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final Sale sale;

  const _SaleTile({required this.sale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: sale.isCredit
            ? Colors.purple.shade100
            : theme.colorScheme.primaryContainer,
        child: Icon(
          sale.isCredit ? Icons.handshake_outlined : Icons.payments_outlined,
          size: 20,
          color: sale.isCredit ? Colors.purple.shade700 : theme.colorScheme.primary,
        ),
      ),
      title: Text(
        Formatters.cop(sale.total),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${Formatters.dateTime(sale.date)}${sale.isCredit ? ' · Fiado' : ''}',
      ),
      children: [
        FutureBuilder(
          future: context.read<SalesProvider>().itemsOf(sale),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Column(
              children: [
                for (final item in snapshot.data!)
                  ListTile(
                    dense: true,
                    title: Text(item.productName),
                    subtitle: Text('${Formatters.cop(item.unitPrice)} c/u'),
                    leading: Text('x${_qty(item.quantity)}'),
                    trailing: Text(Formatters.cop(item.subtotal)),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}
