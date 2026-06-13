import 'package:flutter/foundation.dart';

import '../data/database_helper.dart';
import '../models/employee.dart';

/// Responsables que atienden la tienda (Ferney, Ana y los que se agreguen).
class EmployeesProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Employee> _employees = [];
  bool _loading = false;

  List<Employee> get employees => List.unmodifiable(_employees);
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _employees = await _db.getEmployees();
    _loading = false;
    notifyListeners();
  }

  Future<Employee> add(String name) async {
    final employee = await _db.insertEmployee(Employee(name: name.trim()));
    await load();
    return employee;
  }

  Future<void> remove(int id) async {
    await _db.deleteEmployee(id);
    await load();
  }

  /// Devuelve el nombre del responsable por su id (para mostrarlo en listas).
  String nameOf(int? id) {
    if (id == null) return '';
    final match = _employees.where((e) => e.id == id);
    return match.isEmpty ? '' : match.first.name;
  }
}
