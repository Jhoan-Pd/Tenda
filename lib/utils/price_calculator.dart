/// Lógica de cálculo de precios de venta.
///
/// El precio de venta se obtiene a partir del costo unitario de la factura
/// del proveedor más un porcentaje de ganancia (por defecto 20%, pero
/// configurable por producto). El resultado se redondea hacia arriba al
/// múltiplo de $50 más cercano, como se acostumbra en Colombia.
class PriceCalculator {
  /// Múltiplo al que se redondean los precios (en COP).
  static const int roundingStep = 50;

  /// Calcula el precio de venta: costo + margen%, redondeado a múltiplos de $50.
  static double sellingPrice(double cost, double marginPercent) {
    if (cost <= 0) return 0;
    final raw = cost * (1 + marginPercent / 100);
    return roundUp(raw);
  }

  /// Redondea hacia arriba al múltiplo de [roundingStep] más cercano.
  static double roundUp(double value) {
    if (value <= 0) return 0;
    return (value / roundingStep).ceil() * roundingStep.toDouble();
  }

  /// Ganancia en pesos por unidad.
  static double profitPerUnit(double cost, double marginPercent) {
    return sellingPrice(cost, marginPercent) - cost;
  }

  /// Margen real (%) después del redondeo.
  static double effectiveMargin(double cost, double marginPercent) {
    if (cost <= 0) return 0;
    return (sellingPrice(cost, marginPercent) - cost) / cost * 100;
  }
}
