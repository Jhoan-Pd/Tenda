import 'package:flutter_test/flutter_test.dart';
import 'package:tenda/models/cash_closing.dart';

void main() {
  group('CashClosing (cuadre de caja)', () {
    CashClosing build({
      double opening = 50000,
      double salesCash = 200000,
      double salesCredit = 30000,
      double creditPayments = 10000,
      double rechargesAmount = 40000,
      double rechargesProfit = 3000,
      double debtsPaid = 80000,
      double otherExpenses = 0,
      double productProfit = 45000,
      double counted = 220000,
    }) {
      return CashClosing(
        openingBalance: opening,
        salesCash: salesCash,
        salesCredit: salesCredit,
        creditPayments: creditPayments,
        rechargesAmount: rechargesAmount,
        rechargesProfit: rechargesProfit,
        debtsPaid: debtsPaid,
        otherExpenses: otherExpenses,
        productProfit: productProfit,
        countedCash: counted,
      );
    }

    test('efectivo esperado suma entradas y resta salidas', () {
      final c = build();
      // 50.000 + 200.000 + 40.000 + 10.000 - 80.000 - 0 = 220.000
      expect(c.expectedCash, 220000);
    });

    test('la caja cuadra cuando contado == esperado', () {
      final c = build(counted: 220000);
      expect(c.difference, 0);
    });

    test('detecta faltante de efectivo', () {
      final c = build(counted: 210000);
      expect(c.difference, -10000);
    });

    test('detecta sobrante de efectivo', () {
      final c = build(counted: 225000);
      expect(c.difference, 5000);
    });

    test('la ganancia suma productos y comisión de recargas, no el monto recargado', () {
      final c = build(productProfit: 45000, rechargesProfit: 3000, rechargesAmount: 40000);
      // Ganancia = 45.000 + 3.000 (NO se suman los 40.000 de recargas)
      expect(c.totalProfit, 48000);
    });

    test('los gastos extra reducen el efectivo esperado', () {
      final c = build(otherExpenses: 20000);
      expect(c.expectedCash, 200000);
    });
  });
}
