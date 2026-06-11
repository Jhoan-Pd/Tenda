import '../utils/price_calculator.dart';

/// Producto del inventario.
class Product {
  final int? id;
  final String name;
  final String category;
  final String? barcode;

  /// Costo unitario según factura del proveedor (COP).
  final double cost;

  /// Porcentaje de ganancia aplicado a este producto.
  final double marginPercent;

  /// Precio de venta al público (COP). Se calcula con [PriceCalculator]
  /// pero puede ajustarse manualmente.
  final double price;

  /// Unidades disponibles.
  final double stock;

  /// Cuando el stock llega a este nivel se genera una alerta.
  final double minStock;

  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    this.id,
    required this.name,
    this.category = 'General',
    this.barcode,
    required this.cost,
    required this.marginPercent,
    required this.price,
    required this.stock,
    this.minStock = 5,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isLowStock => stock <= minStock;

  bool get isOutOfStock => stock <= 0;

  double get profitPerUnit => price - cost;

  /// Valor del inventario de este producto al costo.
  double get inventoryValue => cost * stock;

  Product copyWith({
    int? id,
    String? name,
    String? category,
    String? barcode,
    double? cost,
    double? marginPercent,
    double? price,
    double? stock,
    double? minStock,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
      cost: cost ?? this.cost,
      marginPercent: marginPercent ?? this.marginPercent,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'barcode': barcode,
      'cost': cost,
      'marginPercent': marginPercent,
      'price': price,
      'stock': stock,
      'minStock': minStock,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: (map['category'] as String?) ?? 'General',
      barcode: map['barcode'] as String?,
      cost: (map['cost'] as num).toDouble(),
      marginPercent: (map['marginPercent'] as num).toDouble(),
      price: (map['price'] as num).toDouble(),
      stock: (map['stock'] as num).toDouble(),
      minStock: (map['minStock'] as num?)?.toDouble() ?? 5,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
