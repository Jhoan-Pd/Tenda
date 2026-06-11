import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';
import '../models/invoice_item.dart';
import '../models/product.dart';
import '../utils/price_calculator.dart';

/// Estado del inventario de productos.
class InventoryProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Product> _products = [];
  bool _loading = false;

  List<Product> get products => List.unmodifiable(_products);
  bool get loading => _loading;

  /// Productos con stock en el mínimo o por debajo (para alertas).
  List<Product> get lowStockProducts =>
      _products.where((p) => p.isLowStock).toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));

  /// Valor total del inventario al costo.
  double get totalInventoryValue =>
      _products.fold(0.0, (sum, p) => sum + p.inventoryValue);

  /// Valor total del inventario a precio de venta.
  double get totalInventorySaleValue =>
      _products.fold(0.0, (sum, p) => sum + p.price * p.stock);

  List<String> get categories {
    final set = _products.map((p) => p.category).toSet().toList()..sort();
    return set;
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _products = await _db.getProducts();
    _loading = false;
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    await _db.insertProduct(product);
    await load();
  }

  Future<void> updateProduct(Product product) async {
    await _db.updateProduct(product);
    await load();
  }

  Future<void> deleteProduct(int id) async {
    await _db.deleteProduct(id);
    await load();
  }

  /// Suma unidades al stock (entrada de mercancía).
  Future<void> addStock(Product product, double quantity) async {
    await _db.updateProduct(product.copyWith(stock: product.stock + quantity));
    await load();
  }

  List<Product> search(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return products;
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            (p.barcode ?? '').contains(q))
        .toList();
  }

  /// Pasa al inventario los productos extraídos de una factura.
  ///
  /// Si ya existe un producto con el mismo nombre, suma el stock y
  /// actualiza costo, margen y precio; si no, lo crea.
  Future<int> importInvoiceItems(List<InvoiceItem> items) async {
    var imported = 0;
    for (final item in items.where((i) => i.selected)) {
      final price = PriceCalculator.sellingPrice(item.unitCost, item.marginPercent);
      final existing = await _db.findProductByName(item.name);
      if (existing != null) {
        await _db.updateProduct(existing.copyWith(
          cost: item.unitCost,
          marginPercent: item.marginPercent,
          price: price,
          stock: existing.stock + item.quantity,
        ));
      } else {
        await _db.insertProduct(Product(
          name: item.name,
          cost: item.unitCost,
          marginPercent: item.marginPercent,
          price: price,
          stock: item.quantity,
        ));
      }
      imported++;
    }
    await load();
    return imported;
  }
}
