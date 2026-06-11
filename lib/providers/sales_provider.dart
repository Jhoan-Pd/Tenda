import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/sale.dart';

/// Carrito de venta actual e historial de ventas.
class SalesProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  final List<SaleItem> _cart = [];
  List<Sale> _todaySales = [];

  List<SaleItem> get cart => List.unmodifiable(_cart);
  List<Sale> get todaySales => List.unmodifiable(_todaySales);

  double get cartTotal => _cart.fold(0.0, (sum, i) => sum + i.subtotal);

  double get todayTotal => _todaySales.fold(0.0, (sum, s) => sum + s.total);

  int get todayCount => _todaySales.length;

  Future<void> loadToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    _todaySales = await _db.getSales(from: start, to: end);
    notifyListeners();
  }

  void addToCart(Product product, {double quantity = 1}) {
    final index = _cart.indexWhere((i) => i.productId == product.id);
    if (index >= 0) {
      _cart[index] = _cart[index].copyWith(quantity: _cart[index].quantity + quantity);
    } else {
      _cart.add(SaleItem(
        productId: product.id!,
        productName: product.name,
        quantity: quantity,
        unitPrice: product.price,
      ));
    }
    notifyListeners();
  }

  void updateQuantity(SaleItem item, double quantity) {
    final index = _cart.indexOf(item);
    if (index < 0) return;
    if (quantity <= 0) {
      _cart.removeAt(index);
    } else {
      _cart[index] = item.copyWith(quantity: quantity);
    }
    notifyListeners();
  }

  void removeFromCart(SaleItem item) {
    _cart.remove(item);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  /// Cobra el carrito. Si [creditCustomer] no es nulo, la venta queda fiada
  /// y se carga a la cuenta del cliente.
  Future<void> checkout({Customer? creditCustomer}) async {
    if (_cart.isEmpty) return;
    final total = cartTotal;
    final sale = Sale(
      total: total,
      customerId: creditCustomer?.id,
      isCredit: creditCustomer != null,
    );
    await _db.insertSale(sale, List.of(_cart));
    if (creditCustomer != null) {
      final detail = _cart.map((i) => '${i.productName} x${_fmtQty(i.quantity)}').join(', ');
      await _db.insertCreditEntry(CreditEntry(
        customerId: creditCustomer.id!,
        amount: total,
        isPayment: false,
        description: detail,
      ));
    }
    _cart.clear();
    await loadToday();
  }

  Future<List<Sale>> salesBetween(DateTime from, DateTime to) =>
      _db.getSales(from: from, to: to);

  Future<List<SaleItem>> itemsOf(Sale sale) => _db.getSaleItems(sale.id!);

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}
