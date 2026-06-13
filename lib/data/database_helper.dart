import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/cash_closing.dart';
import '../models/customer.dart';
import '../models/debt.dart';
import '../models/employee.dart';
import '../models/product.dart';
import '../models/recharge.dart';
import '../models/sale.dart';

/// Acceso a la base de datos local SQLite.
///
/// Todo se guarda en el teléfono: no requiere internet ni servicios pagos.
class DatabaseHelper {
  static const _dbName = 'tenda.db';
  static const _dbVersion = 2;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createTables,
      onUpgrade: _upgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'General',
        barcode TEXT,
        cost REAL NOT NULL,
        marginPercent REAL NOT NULL,
        price REAL NOT NULL,
        stock REAL NOT NULL,
        minStock REAL NOT NULL DEFAULT 5,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        totalAmount REAL NOT NULL,
        dueDate TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        paid INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE debt_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debtId INTEGER NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
        amount REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total REAL NOT NULL,
        customerId INTEGER,
        isCredit INTEGER NOT NULL DEFAULT 0,
        employeeId INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        saleId INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        quantity REAL NOT NULL,
        unitPrice REAL NOT NULL,
        unitCost REAL NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE credit_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerId INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
        amount REAL NOT NULL,
        isPayment INTEGER NOT NULL DEFAULT 0,
        description TEXT NOT NULL DEFAULT '',
        employeeId INTEGER,
        date TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE recharges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        profit REAL NOT NULL DEFAULT 0,
        employeeId INTEGER,
        date TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE cash_closings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        openingBalance REAL NOT NULL,
        salesCash REAL NOT NULL,
        salesCredit REAL NOT NULL,
        creditPayments REAL NOT NULL,
        rechargesAmount REAL NOT NULL,
        rechargesProfit REAL NOT NULL,
        debtsPaid REAL NOT NULL,
        otherExpenses REAL NOT NULL,
        productProfit REAL NOT NULL,
        countedCash REAL NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
    await _seedEmployees(db);
  }

  /// Migra bases de datos creadas con la versión 1 (sin recargas/caja).
  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE sales ADD COLUMN employeeId INTEGER');
      await db.execute(
          'ALTER TABLE sale_items ADD COLUMN unitCost REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE credit_entries ADD COLUMN employeeId INTEGER');
      await db.execute('''
        CREATE TABLE employees (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE recharges (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          profit REAL NOT NULL DEFAULT 0,
          employeeId INTEGER,
          date TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE cash_closings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          openingBalance REAL NOT NULL,
          salesCash REAL NOT NULL,
          salesCredit REAL NOT NULL,
          creditPayments REAL NOT NULL,
          rechargesAmount REAL NOT NULL,
          rechargesProfit REAL NOT NULL,
          debtsPaid REAL NOT NULL,
          otherExpenses REAL NOT NULL,
          productProfit REAL NOT NULL,
          countedCash REAL NOT NULL,
          note TEXT NOT NULL DEFAULT ''
        )
      ''');
      await _seedEmployees(db);
    }
  }

  /// Responsables que vienen por defecto.
  Future<void> _seedEmployees(Database db) async {
    final existing = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM employees'));
    if ((existing ?? 0) == 0) {
      await db.insert('employees', {'name': 'Ferney'});
      await db.insert('employees', {'name': 'Ana'});
    }
  }

  // ---------------- Productos ----------------

  Future<List<Product>> getProducts() async {
    final db = await database;
    final rows = await db.query('products', orderBy: 'name COLLATE NOCASE');
    return rows.map(Product.fromMap).toList();
  }

  Future<Product> insertProduct(Product product) async {
    final db = await database;
    final map = product.toMap()..remove('id');
    final id = await db.insert('products', map);
    return product.copyWith(id: id);
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  /// Busca un producto con el mismo nombre (para fusionar al escanear facturas).
  Future<Product?> findProductByName(String name) async {
    final db = await database;
    final rows = await db.query(
      'products',
      where: 'LOWER(name) = ?',
      whereArgs: [name.toLowerCase().trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  // ---------------- Deudas ----------------

  Future<List<Debt>> getDebts() async {
    final db = await database;
    final rows = await db.query('debts', orderBy: 'paid ASC, dueDate ASC');
    return rows.map(Debt.fromMap).toList();
  }

  Future<Debt> insertDebt(Debt debt) async {
    final db = await database;
    final map = debt.toMap()..remove('id');
    final id = await db.insert('debts', map);
    return debt.copyWith(id: id);
  }

  Future<void> updateDebt(Debt debt) async {
    final db = await database;
    await db.update('debts', debt.toMap(), where: 'id = ?', whereArgs: [debt.id]);
  }

  Future<void> deleteDebt(int id) async {
    final db = await database;
    await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DebtPayment>> getDebtPayments(int debtId) async {
    final db = await database;
    final rows = await db.query(
      'debt_payments',
      where: 'debtId = ?',
      whereArgs: [debtId],
      orderBy: 'date DESC',
    );
    return rows.map(DebtPayment.fromMap).toList();
  }

  Future<List<DebtPayment>> getAllDebtPayments() async {
    final db = await database;
    final rows = await db.query('debt_payments', orderBy: 'date DESC');
    return rows.map(DebtPayment.fromMap).toList();
  }

  Future<void> insertDebtPayment(DebtPayment payment) async {
    final db = await database;
    final map = payment.toMap()..remove('id');
    await db.insert('debt_payments', map);
  }

  // ---------------- Ventas ----------------

  /// Registra la venta, sus renglones y descuenta el stock en una transacción.
  Future<int> insertSale(Sale sale, List<SaleItem> items) async {
    final db = await database;
    return db.transaction((txn) async {
      final saleMap = sale.toMap()..remove('id');
      final saleId = await txn.insert('sales', saleMap);
      for (final item in items) {
        final itemMap = item.toMap()
          ..remove('id')
          ..['saleId'] = saleId;
        await txn.insert('sale_items', itemMap);
        // Solo descuenta stock de productos reales del inventario (id > 0).
        if (item.productId > 0) {
          await txn.rawUpdate(
            'UPDATE products SET stock = MAX(0, stock - ?), updatedAt = ? WHERE id = ?',
            [item.quantity, DateTime.now().toIso8601String(), item.productId],
          );
        }
      }
      return saleId;
    });
  }

  Future<List<Sale>> getSales({DateTime? from, DateTime? to}) async {
    final db = await database;
    String? where;
    List<Object?>? args;
    if (from != null && to != null) {
      where = 'date >= ? AND date < ?';
      args = [from.toIso8601String(), to.toIso8601String()];
    }
    final rows = await db.query('sales', where: where, whereArgs: args, orderBy: 'date DESC');
    return rows.map(Sale.fromMap).toList();
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final db = await database;
    final rows = await db.query('sale_items', where: 'saleId = ?', whereArgs: [saleId]);
    return rows.map(SaleItem.fromMap).toList();
  }

  // ---------------- Clientes y fiados ----------------

  Future<List<Customer>> getCustomers() async {
    final db = await database;
    final rows = await db.query('customers', orderBy: 'name COLLATE NOCASE');
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer> insertCustomer(Customer customer) async {
    final db = await database;
    final map = customer.toMap()..remove('id');
    final id = await db.insert('customers', map);
    return Customer(id: id, name: customer.name, phone: customer.phone);
  }

  Future<void> deleteCustomer(int id) async {
    final db = await database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CreditEntry>> getCreditEntries(int customerId) async {
    final db = await database;
    final rows = await db.query(
      'credit_entries',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'date DESC',
    );
    return rows.map(CreditEntry.fromMap).toList();
  }

  Future<void> insertCreditEntry(CreditEntry entry) async {
    final db = await database;
    final map = entry.toMap()..remove('id');
    await db.insert('credit_entries', map);
  }

  /// Saldo pendiente por cliente (cargos menos abonos).
  Future<Map<int, double>> getCustomerBalances() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT customerId,
             SUM(CASE WHEN isPayment = 1 THEN -amount ELSE amount END) AS balance
      FROM credit_entries
      GROUP BY customerId
    ''');
    return {
      for (final row in rows)
        row['customerId'] as int: (row['balance'] as num?)?.toDouble() ?? 0,
    };
  }

  // ---------------- Empleados / responsables ----------------

  Future<List<Employee>> getEmployees() async {
    final db = await database;
    final rows = await db.query('employees', orderBy: 'name COLLATE NOCASE');
    return rows.map(Employee.fromMap).toList();
  }

  Future<Employee> insertEmployee(Employee employee) async {
    final db = await database;
    final id = await db.insert('employees', {'name': employee.name});
    return Employee(id: id, name: employee.name);
  }

  Future<void> deleteEmployee(int id) async {
    final db = await database;
    await db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Recargas ----------------

  Future<void> insertRecharge(Recharge recharge) async {
    final db = await database;
    final map = recharge.toMap()..remove('id');
    await db.insert('recharges', map);
  }

  Future<List<Recharge>> getRecharges({DateTime? from, DateTime? to}) async {
    final db = await database;
    String? where;
    List<Object?>? args;
    if (from != null && to != null) {
      where = 'date >= ? AND date < ?';
      args = [from.toIso8601String(), to.toIso8601String()];
    }
    final rows =
        await db.query('recharges', where: where, whereArgs: args, orderBy: 'date DESC');
    return rows.map(Recharge.fromMap).toList();
  }

  Future<void> deleteRecharge(int id) async {
    final db = await database;
    await db.delete('recharges', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Cuadre de caja ----------------

  /// Calcula los movimientos del día (rango [from, to)) para el cierre de caja.
  Future<DayMovements> getDayMovements(DateTime from, DateTime to) async {
    final db = await database;
    final range = [from.toIso8601String(), to.toIso8601String()];

    final salesRows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN isCredit = 0 THEN total ELSE 0 END), 0) AS cash,
        COALESCE(SUM(CASE WHEN isCredit = 1 THEN total ELSE 0 END), 0) AS credit
      FROM sales WHERE date >= ? AND date < ?
    ''', range);

    final profitRows = await db.rawQuery('''
      SELECT COALESCE(SUM((si.unitPrice - si.unitCost) * si.quantity), 0) AS profit
      FROM sale_items si
      JOIN sales s ON s.id = si.saleId
      WHERE s.date >= ? AND s.date < ?
    ''', range);

    final rechargeRows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS amount, COALESCE(SUM(profit), 0) AS profit
      FROM recharges WHERE date >= ? AND date < ?
    ''', range);

    final creditPayRows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM credit_entries WHERE isPayment = 1 AND date >= ? AND date < ?
    ''', range);

    final debtsPaidRows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM debt_payments WHERE date >= ? AND date < ?
    ''', range);

    double num0(Object? v) => (v as num?)?.toDouble() ?? 0;

    return DayMovements(
      salesCash: num0(salesRows.first['cash']),
      salesCredit: num0(salesRows.first['credit']),
      productProfit: num0(profitRows.first['profit']),
      rechargesAmount: num0(rechargeRows.first['amount']),
      rechargesProfit: num0(rechargeRows.first['profit']),
      creditPayments: num0(creditPayRows.first['total']),
      debtsPaid: num0(debtsPaidRows.first['total']),
    );
  }

  Future<void> insertCashClosing(CashClosing closing) async {
    final db = await database;
    final map = closing.toMap()..remove('id');
    await db.insert('cash_closings', map);
  }

  Future<List<CashClosing>> getCashClosings() async {
    final db = await database;
    final rows = await db.query('cash_closings', orderBy: 'date DESC');
    return rows.map(CashClosing.fromMap).toList();
  }

  /// Última base de caja usada (para sugerir la base inicial del próximo cierre).
  Future<double> getLastCountedCash() async {
    final db = await database;
    final rows = await db.query('cash_closings', orderBy: 'date DESC', limit: 1);
    if (rows.isEmpty) return 0;
    return (rows.first['countedCash'] as num?)?.toDouble() ?? 0;
  }
}
