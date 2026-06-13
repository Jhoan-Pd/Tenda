/// Cliente al que se le fía (crédito informal típico de tienda de barrio).
class Customer {
  final int? id;
  final String name;
  final String phone;

  Customer({this.id, required this.name, this.phone = ''});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'phone': phone};
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: (map['phone'] as String?) ?? '',
    );
  }
}

/// Movimiento en la cuenta de un cliente: cargo (fiado) o abono (pago).
class CreditEntry {
  final int? id;
  final int customerId;

  /// Positivo siempre; [isPayment] indica si resta o suma a la deuda.
  final double amount;
  final bool isPayment;
  final String description;

  /// Responsable que anotó el fiado o recibió el abono (Ferney, Ana, ...).
  final int? employeeId;
  final DateTime date;

  CreditEntry({
    this.id,
    required this.customerId,
    required this.amount,
    required this.isPayment,
    this.description = '',
    this.employeeId,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'amount': amount,
      'isPayment': isPayment ? 1 : 0,
      'description': description,
      'employeeId': employeeId,
      'date': date.toIso8601String(),
    };
  }

  factory CreditEntry.fromMap(Map<String, dynamic> map) {
    return CreditEntry(
      id: map['id'] as int?,
      customerId: map['customerId'] as int,
      amount: (map['amount'] as num).toDouble(),
      isPayment: (map['isPayment'] as int? ?? 0) == 1,
      description: (map['description'] as String?) ?? '',
      employeeId: map['employeeId'] as int?,
      date: DateTime.parse(map['date'] as String),
    );
  }
}

/// Cliente con el saldo que debe.
class CustomerWithBalance {
  final Customer customer;
  final double balance;

  CustomerWithBalance({required this.customer, required this.balance});
}
