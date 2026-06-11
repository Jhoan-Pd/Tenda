import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';
import '../models/debt.dart';

/// Estado de las facturas pendientes (deudas con proveedores) y sus abonos.
class DebtsProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<DebtWithPayments> _debts = [];
  bool _loading = false;

  List<DebtWithPayments> get debts => List.unmodifiable(_debts);
  bool get loading => _loading;

  List<DebtWithPayments> get pending => _debts.where((d) => !d.isSettled).toList();

  List<DebtWithPayments> get settled => _debts.where((d) => d.isSettled).toList();

  /// Deudas vencidas o que vencen en los próximos 7 días (para alertas).
  List<DebtWithPayments> get dueSoonOrOverdue =>
      pending.where((d) => d.isOverdue || d.isDueSoon).toList();

  double get totalOwed => pending.fold(0.0, (sum, d) => sum + d.remaining);

  /// Total que se debería ahorrar HOY sumando todas las deudas pendientes.
  double get totalDailySaving => pending.fold(0.0, (sum, d) => sum + d.dailySaving);

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    final debts = await _db.getDebts();
    final allPayments = await _db.getAllDebtPayments();
    _debts = debts
        .map((debt) => DebtWithPayments(
              debt: debt,
              payments: allPayments.where((p) => p.debtId == debt.id).toList(),
            ))
        .toList();
    _loading = false;
    notifyListeners();
  }

  Future<void> addDebt(Debt debt) async {
    await _db.insertDebt(debt);
    await load();
  }

  Future<void> updateDebt(Debt debt) async {
    await _db.updateDebt(debt);
    await load();
  }

  Future<void> deleteDebt(int id) async {
    await _db.deleteDebt(id);
    await load();
  }

  /// Registra un abono; si con él se completa el total, marca la deuda pagada.
  Future<void> addPayment(DebtWithPayments debt, double amount) async {
    await _db.insertDebtPayment(DebtPayment(debtId: debt.debt.id!, amount: amount));
    if (debt.totalPaid + amount >= debt.debt.totalAmount) {
      await _db.updateDebt(debt.debt.copyWith(paid: true));
    }
    await load();
  }

  Future<void> markPaid(DebtWithPayments debt) async {
    final remaining = debt.remaining;
    if (remaining > 0) {
      await _db.insertDebtPayment(DebtPayment(debtId: debt.debt.id!, amount: remaining));
    }
    await _db.updateDebt(debt.debt.copyWith(paid: true));
    await load();
  }
}
