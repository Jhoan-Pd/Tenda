/// Cierre/cuadre de caja de un día.
///
/// Guarda una "foto" de los movimientos del día para que el histórico
/// quede fijo aunque después cambien los datos. La cuenta es:
///
///   Efectivo esperado = base inicial
///                     + ventas de contado
///                     + recargas cobradas
///                     + abonos de fiados recibidos
///                     − facturas/deudas pagadas
///                     − otros gastos/retiros
///
///   Diferencia (descuadre) = efectivo contado − efectivo esperado
///   Ganancia del día        = ganancia de productos + comisión de recargas
class CashClosing {
  final int? id;
  final DateTime date;

  final double openingBalance; // base con que se abrió la caja
  final double salesCash; // ventas de contado (efectivo)
  final double salesCredit; // ventas fiadas (informativo, no entra a caja)
  final double creditPayments; // abonos de fiados recibidos
  final double rechargesAmount; // valor total de recargas vendidas
  final double rechargesProfit; // comisión de las recargas
  final double debtsPaid; // facturas/deudas pagadas a proveedores
  final double otherExpenses; // retiros u otros gastos
  final double productProfit; // ganancia por margen de los productos vendidos
  final double countedCash; // efectivo realmente contado al cerrar
  final String note;

  CashClosing({
    this.id,
    DateTime? date,
    required this.openingBalance,
    required this.salesCash,
    required this.salesCredit,
    required this.creditPayments,
    required this.rechargesAmount,
    required this.rechargesProfit,
    required this.debtsPaid,
    required this.otherExpenses,
    required this.productProfit,
    required this.countedCash,
    this.note = '',
  }) : date = date ?? DateTime.now();

  double get expectedCash =>
      openingBalance +
      salesCash +
      rechargesAmount +
      creditPayments -
      debtsPaid -
      otherExpenses;

  /// Positivo = sobra efectivo; negativo = falta efectivo.
  double get difference => countedCash - expectedCash;

  double get totalProfit => productProfit + rechargesProfit;

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'openingBalance': openingBalance,
        'salesCash': salesCash,
        'salesCredit': salesCredit,
        'creditPayments': creditPayments,
        'rechargesAmount': rechargesAmount,
        'rechargesProfit': rechargesProfit,
        'debtsPaid': debtsPaid,
        'otherExpenses': otherExpenses,
        'productProfit': productProfit,
        'countedCash': countedCash,
        'note': note,
      };

  factory CashClosing.fromMap(Map<String, dynamic> map) => CashClosing(
        id: map['id'] as int?,
        date: DateTime.parse(map['date'] as String),
        openingBalance: (map['openingBalance'] as num).toDouble(),
        salesCash: (map['salesCash'] as num).toDouble(),
        salesCredit: (map['salesCredit'] as num).toDouble(),
        creditPayments: (map['creditPayments'] as num).toDouble(),
        rechargesAmount: (map['rechargesAmount'] as num).toDouble(),
        rechargesProfit: (map['rechargesProfit'] as num).toDouble(),
        debtsPaid: (map['debtsPaid'] as num).toDouble(),
        otherExpenses: (map['otherExpenses'] as num).toDouble(),
        productProfit: (map['productProfit'] as num).toDouble(),
        countedCash: (map['countedCash'] as num).toDouble(),
        note: (map['note'] as String?) ?? '',
      );
}

/// Resumen en vivo de los movimientos del día (antes de cerrar la caja).
class DayMovements {
  final double salesCash;
  final double salesCredit;
  final double creditPayments;
  final double rechargesAmount;
  final double rechargesProfit;
  final double debtsPaid;
  final double productProfit;

  const DayMovements({
    this.salesCash = 0,
    this.salesCredit = 0,
    this.creditPayments = 0,
    this.rechargesAmount = 0,
    this.rechargesProfit = 0,
    this.debtsPaid = 0,
    this.productProfit = 0,
  });
}
