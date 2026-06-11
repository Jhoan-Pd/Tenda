import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/debts_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/settings_provider.dart';
import 'alerts/alerts_screen.dart';
import 'credit/credit_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'debts/debts_screen.dart';
import 'products/products_screen.dart';
import 'sales/sale_screen.dart';
import 'settings/settings_screen.dart';

/// Pantalla principal con navegación inferior.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _titles = ['Inicio', 'Inventario', 'Vender', 'Deudas', 'Fiados'];

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final debts = context.watch<DebtsProvider>();
    final settings = context.watch<SettingsProvider>();

    final alertCount =
        inventory.lowStockProducts.length + debts.dueSoonOrOverdue.length;

    final screens = const [
      DashboardScreen(),
      ProductsScreen(),
      SaleScreen(),
      DebtsScreen(),
      CreditScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? settings.storeName : _titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Alertas',
            icon: Badge(
              isLabelVisible: alertCount > 0,
              label: Text('$alertCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlertsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventario'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'Vender'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Deudas'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Fiados'),
        ],
      ),
    );
  }
}
