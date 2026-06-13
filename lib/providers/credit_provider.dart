import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';
import '../models/customer.dart';

/// Estado de los clientes con cuenta de fiado.
class CreditProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<CustomerWithBalance> _customers = [];
  bool _loading = false;

  List<CustomerWithBalance> get customers => List.unmodifiable(_customers);
  bool get loading => _loading;

  double get totalCredit =>
      _customers.fold(0.0, (sum, c) => sum + (c.balance > 0 ? c.balance : 0));

  /// Clientes que deben algo, ordenados de mayor a menor deuda.
  List<CustomerWithBalance> get debtors =>
      _customers.where((c) => c.balance > 0).toList()
        ..sort((a, b) => b.balance.compareTo(a.balance));

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    final customers = await _db.getCustomers();
    final balances = await _db.getCustomerBalances();
    _customers = customers
        .map((c) => CustomerWithBalance(customer: c, balance: balances[c.id] ?? 0))
        .toList();
    _loading = false;
    notifyListeners();
  }

  Future<Customer> addCustomer(String name, String phone) async {
    final customer = await _db.insertCustomer(Customer(name: name, phone: phone));
    await load();
    return customer;
  }

  Future<void> deleteCustomer(int id) async {
    await _db.deleteCustomer(id);
    await load();
  }

  Future<void> addCharge(
    Customer customer,
    double amount,
    String description, {
    int? employeeId,
  }) async {
    await _db.insertCreditEntry(CreditEntry(
      customerId: customer.id!,
      amount: amount,
      isPayment: false,
      description: description,
      employeeId: employeeId,
    ));
    await load();
  }

  Future<void> addPayment(Customer customer, double amount, {int? employeeId}) async {
    await _db.insertCreditEntry(CreditEntry(
      customerId: customer.id!,
      amount: amount,
      isPayment: true,
      description: 'Abono',
      employeeId: employeeId,
    ));
    await load();
  }

  Future<List<CreditEntry>> entriesOf(Customer customer) =>
      _db.getCreditEntries(customer.id!);
}
