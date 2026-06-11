/// Producto extraído de una factura de proveedor mediante IA (Grok).
///
/// Es mutable a propósito: en la pantalla de revisión el usuario puede
/// corregir lo que la IA haya leído mal antes de pasarlo al inventario.
class InvoiceItem {
  String name;
  double quantity;

  /// Costo unitario leído de la factura (COP).
  double unitCost;

  /// Margen de ganancia que el usuario asigna a este producto.
  double marginPercent;

  /// Si está seleccionado para agregarse al inventario.
  bool selected;

  InvoiceItem({
    required this.name,
    required this.quantity,
    required this.unitCost,
    this.marginPercent = 20,
    this.selected = true,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json, {double defaultMargin = 20}) {
    final qty = (json['cantidad'] as num?)?.toDouble() ?? 1;
    double unitCost = (json['precio_unitario'] as num?)?.toDouble() ?? 0;
    // Si la IA solo encontró el total del renglón, derivamos el unitario.
    final total = (json['precio_total'] as num?)?.toDouble();
    if (unitCost == 0 && total != null && qty > 0) {
      unitCost = total / qty;
    }
    return InvoiceItem(
      name: (json['nombre'] as String?)?.trim() ?? 'Producto sin nombre',
      quantity: qty,
      unitCost: unitCost,
      marginPercent: defaultMargin,
    );
  }
}
