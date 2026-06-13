/// Venta de una recarga (planes de minutos o datos a celulares).
///
/// En el cuadre de caja, el [amount] entra como efectivo recibido del cliente,
/// pero NO es ganancia de la tienda: solo la [profit] (comisión) cuenta como
/// ganancia. Por eso el cierre "resta" el valor de las recargas de la ganancia.
class Recharge {
  final int? id;

  /// Valor recargado al celular del cliente (lo que paga en efectivo).
  final double amount;

  /// Ganancia/comisión que deja la recarga a la tienda.
  final double profit;

  /// Quién hizo la recarga.
  final int? employeeId;

  final DateTime date;

  Recharge({
    this.id,
    required this.amount,
    this.profit = 0,
    this.employeeId,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'profit': profit,
        'employeeId': employeeId,
        'date': date.toIso8601String(),
      };

  factory Recharge.fromMap(Map<String, dynamic> map) => Recharge(
        id: map['id'] as int?,
        amount: (map['amount'] as num).toDouble(),
        profit: (map['profit'] as num?)?.toDouble() ?? 0,
        employeeId: map['employeeId'] as int?,
        date: DateTime.parse(map['date'] as String),
      );
}
