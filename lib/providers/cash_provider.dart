import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';
import '../models/cash_closing.dart';
import '../models/recharge.dart';

/// Estado del cuadre de caja: recargas del día, movimientos y cierres.
class CashProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  DayMovements _today = const DayMovements();
  List<Recharge> _todayRecharges = [];
  List<CashClosing> _closings = [];
  bool _loading = false;

  DayMovements get today => _today;
  List<Recharge> get todayRecharges => List.unmodifiable(_todayRecharges);
  List<CashClosing> get closings => List.unmodifiable(_closings);
  bool get loading => _loading;

  static (DateTime, DateTime) _todayRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return (start, start.add(const Duration(days: 1)));
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    final (start, end) = _todayRange();
    _today = await _db.getDayMovements(start, end);
    _todayRecharges = await _db.getRecharges(from: start, to: end);
    _closings = await _db.getCashClosings();
    _loading = false;
    notifyListeners();
  }

  Future<void> addRecharge(double amount, double profit, int? employeeId) async {
    await _db.insertRecharge(
      Recharge(amount: amount, profit: profit, employeeId: employeeId),
    );
    await load();
  }

  Future<void> deleteRecharge(int id) async {
    await _db.deleteRecharge(id);
    await load();
  }

  /// Base inicial sugerida = efectivo contado en el último cierre.
  Future<double> suggestedOpeningBalance() => _db.getLastCountedCash();

  Future<void> saveClosing({
    required double openingBalance,
    required double countedCash,
    required double otherExpenses,
    String note = '',
  }) async {
    final m = _today;
    await _db.insertCashClosing(CashClosing(
      openingBalance: openingBalance,
      salesCash: m.salesCash,
      salesCredit: m.salesCredit,
      creditPayments: m.creditPayments,
      rechargesAmount: m.rechargesAmount,
      rechargesProfit: m.rechargesProfit,
      debtsPaid: m.debtsPaid,
      otherExpenses: otherExpenses,
      productProfit: m.productProfit,
      countedCash: countedCash,
      note: note,
    ));
    await load();
  }

  /// Efectivo esperado en caja con la base y gastos dados.
  double expectedCash(double openingBalance, double otherExpenses) {
    final m = _today;
    return openingBalance +
        m.salesCash +
        m.rechargesAmount +
        m.creditPayments -
        m.debtsPaid -
        otherExpenses;
  }

  double get todayProfit => _today.productProfit + _today.rechargesProfit;
}
