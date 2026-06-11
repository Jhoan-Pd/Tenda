import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/customer.dart';
import '../models/debt.dart';
import '../models/product.dart';
import '../models/sale.dart';

/// Acceso a la base de datos local SQLite.
///
/// Todo se guarda en el teléfono: no requiere internet ni servicios pagos.
class DatabaseHelper {
  static const _dbName = 'tenda.db';
  static const _dbVersion = 1;

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
        isCredit INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        saleId INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        quantity REAL NOT NULL,
        unitPrice REAL NOT NULL
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
        date TEXT NOT NULL
      )
    ''');
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
        await txn.rawUpdate(
          'UPDATE products SET stock = MAX(0, stock - ?), updatedAt = ? WHERE id = ?',
          [item.quantity, DateTime.now().toIso8601String(), item.productId],
        );
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
}
