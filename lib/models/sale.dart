/// Venta registrada (puede ser de contado o fiada a un cliente).
class Sale {
  final int? id;
  final DateTime date;
  final double total;

  /// Si la venta fue fiada, cliente asociado.
  final int? customerId;
  final bool isCredit;

  Sale({
    this.id,
    DateTime? date,
    required this.total,
    this.customerId,
    this.isCredit = false,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'total': total,
      'customerId': customerId,
      'isCredit': isCredit ? 1 : 0,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      total: (map['total'] as num).toDouble(),
      customerId: map['customerId'] as int?,
      isCredit: (map['isCredit'] as int? ?? 0) == 1,
    );
  }
}

/// Renglón de una venta.
class SaleItem {
  final int? id;
  final int? saleId;
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;

  SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;

  SaleItem copyWith({double? quantity}) {
    return SaleItem(
      id: id,
      saleId: saleId,
      productId: productId,
      productName: productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleId': saleId,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as int?,
      saleId: map['saleId'] as int?,
      productId: map['productId'] as int,
      productName: map['productName'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unitPrice'] as num).toDouble(),
    );
  }
}
