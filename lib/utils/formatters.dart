import 'package:intl/intl.dart';

/// Utilidades de formato para pesos colombianos (COP) y fechas.
class Formatters {
  static final NumberFormat _cop = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy h:mm a');

  /// Formatea un valor como pesos colombianos: 12500 -> $ 12.500
  static String cop(num value) => _cop.format(value);

  static String date(DateTime d) => _date.format(d);

  static String dateTime(DateTime d) => _dateTime.format(d);

  /// Convierte texto con separadores colombianos ("12.500" o "12500") a double.
  static double? parseMoney(String text) {
    final clean = text.replaceAll(r'$', '').replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(clean);
  }
}
