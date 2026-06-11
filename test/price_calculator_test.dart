import 'package:flutter_test/flutter_test.dart';
import 'package:tenda/models/debt.dart';
import 'package:tenda/utils/price_calculator.dart';

void main() {
  group('PriceCalculator', () {
    test('aplica el 20% de ganancia y redondea a \$50', () {
      // 1000 * 1.20 = 1200 -> ya es múltiplo de 50
      expect(PriceCalculator.sellingPrice(1000, 20), 1200);
      // 1130 * 1.20 = 1356 -> redondea hacia arriba a 1400
      expect(PriceCalculator.sellingPrice(1130, 20), 1400);
    });

    test('acepta márgenes distintos al 20%', () {
      // 2000 * 1.35 = 2700
      expect(PriceCalculator.sellingPrice(2000, 35), 2700);
      // 500 * 1.10 = 550
      expect(PriceCalculator.sellingPrice(500, 10), 550);
    });

    test('margen 0% solo redondea el costo', () {
      expect(PriceCalculator.sellingPrice(980, 0), 1000);
    });

    test('costo inválido devuelve 0', () {
      expect(PriceCalculator.sellingPrice(0, 20), 0);
      expect(PriceCalculator.sellingPrice(-100, 20), 0);
    });

    test('calcula la ganancia por unidad', () {
      // Venta 1200, costo 1000 -> gana 200
      expect(PriceCalculator.profitPerUnit(1000, 20), 200);
    });
  });

  group('DebtWithPayments (plan de ahorro)', () {
    DebtWithPayments buildDebt({
      required double total,
      required int daysFromNow,
      List<double> payments = const [],
    }) {
      final debt = Debt(
        id: 1,
        supplier: 'Proveedor',
        totalAmount: total,
        dueDate: DateTime.now().add(Duration(days: daysFromNow)),
      );
      return DebtWithPayments(
        debt: debt,
        payments: [
          for (final p in payments) DebtPayment(debtId: 1, amount: p),
        ],
      );
    }

    test('ahorro diario divide el saldo entre los días restantes', () {
      final d = buildDebt(total: 100000, daysFromNow: 10);
      expect(d.dailySaving, closeTo(10000, 0.01));
    });

    test('los abonos reducen el saldo y el ahorro diario', () {
      final d = buildDebt(total: 100000, daysFromNow: 10, payments: [40000]);
      expect(d.remaining, 60000);
      expect(d.dailySaving, closeTo(6000, 0.01));
    });

    test('ahorro semanal divide el saldo entre las semanas restantes', () {
      final d = buildDebt(total: 140000, daysFromNow: 14);
      expect(d.weeklySaving, closeTo(70000, 0.01));
    });

    test('deuda vencida exige el saldo completo de inmediato', () {
      final d = buildDebt(total: 50000, daysFromNow: -3);
      expect(d.isOverdue, isTrue);
      expect(d.dailySaving, 50000);
    });

    test('queda saldada cuando los abonos cubren el total', () {
      final d = buildDebt(total: 50000, daysFromNow: 5, payments: [30000, 20000]);
      expect(d.isSettled, isTrue);
      expect(d.remaining, 0);
    });
  });
}
