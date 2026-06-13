/// Interpreta lo que el tendero dicta para armar una venta.
///
/// Entiende el vocabulario típico de tienda de barrio colombiana:
///   "agua de 700"            -> 1 agua a $700
///   "dos panes de 500"       -> 2 panes a $500 c/u
///   "una coca cola de 3000"  -> 1 coca cola a $3000
///   "tres aguas de setecientos, un bon bon bum de 200"
///
/// El precio va después de "de" o "a". Acepta números en dígitos o en
/// palabras ("setecientos", "mil quinientos"). Si no se dicta precio, el
/// nombre queda para buscarlo en el inventario.
class ParsedItem {
  String name;
  double quantity;

  /// Precio dictado ("de 700"). Null si no se dictó (se buscará en inventario).
  double? price;

  ParsedItem({required this.name, this.quantity = 1, this.price});
}

class VoiceParser {
  /// Palabras que separan un producto del siguiente.
  static final _itemSeparators = RegExp(r'\s*(?:,|;|\.| y | mas | más |\n)\s*');

  /// Conectores que anuncian el precio.
  static const _priceConnectors = {'de', 'a', 'por'};

  static const _quantityWords = {
    'un': 1.0, 'una': 1.0, 'uno': 1.0,
    'dos': 2.0, 'tres': 3.0, 'cuatro': 4.0, 'cinco': 5.0,
    'seis': 6.0, 'siete': 7.0, 'ocho': 8.0, 'nueve': 9.0, 'diez': 10.0,
    'once': 11.0, 'doce': 12.0, 'docena': 12.0,
    'media': 0.5, 'medio': 0.5,
  };

  static const _numberWords = {
    'cero': 0, 'un': 1, 'uno': 1, 'una': 1, 'dos': 2, 'tres': 3, 'cuatro': 4,
    'cinco': 5, 'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9, 'diez': 10,
    'once': 11, 'doce': 12, 'trece': 13, 'catorce': 14, 'quince': 15,
    'dieciseis': 16, 'diecisiete': 17, 'dieciocho': 18, 'diecinueve': 19,
    'veinte': 20, 'veintiuno': 21, 'veintidos': 22, 'veintitres': 23,
    'veinticuatro': 24, 'veinticinco': 25, 'veintiseis': 26, 'veintisiete': 27,
    'veintiocho': 28, 'veintinueve': 29, 'treinta': 30, 'cuarenta': 40,
    'cincuenta': 50, 'sesenta': 60, 'setenta': 70, 'ochenta': 80, 'noventa': 90,
    'cien': 100, 'ciento': 100, 'doscientos': 200, 'trescientos': 300,
    'cuatrocientos': 400, 'quinientos': 500, 'seiscientos': 600,
    'setecientos': 700, 'ochocientos': 800, 'novecientos': 900,
    'mil': 1000, 'millon': 1000000, 'millones': 1000000,
  };

  /// Quita tildes y pasa a minúsculas para comparar palabras.
  /// También elimina el punto de miles colombiano dentro de un número
  /// ("1.500" -> "1500") para no confundirlo con un separador de productos.
  static String normalize(String input) {
    var s = input.toLowerCase().trim();
    const from = 'áàäâéèëêíìïîóòöôúùüû';
    const to = 'aaaaeeeeiiiioooouuuu';
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    s = s.replaceAll(RegExp(r'(?<=\d)\.(?=\d)'), '');
    return s;
  }

  /// Convierte una secuencia de palabras/dígitos en un número.
  /// Devuelve null si no hay ningún número reconocible.
  static double? parseNumber(List<String> words) {
    int result = 0;
    int current = 0;
    bool found = false;

    for (final w in words) {
      if (w == 'y' || w.isEmpty) continue;

      // Dígitos directos: "700", "1.500", "1500"
      final digits = w.replaceAll('.', '').replaceAll(',', '');
      final asInt = int.tryParse(digits);
      if (asInt != null) {
        // Un número en dígitos representa el valor completo del precio.
        return (result + current + asInt).toDouble();
      }

      final v = _numberWords[w];
      if (v == null) continue;
      found = true;

      if (v == 1000000) {
        current = current == 0 ? 1 : current;
        result += current * 1000000;
        current = 0;
      } else if (v == 1000) {
        current = current == 0 ? 1 : current;
        result += current * 1000;
        current = 0;
      } else if (v == 100) {
        current = current == 0 ? 100 : current * 100;
      } else {
        current += v;
      }
    }

    if (!found) return null;
    return (result + current).toDouble();
  }

  /// Interpreta el texto completo en una lista de productos.
  static List<ParsedItem> parse(String text) {
    final normalized = normalize(text);
    if (normalized.isEmpty) return [];

    final segments = normalized
        .split(_itemSeparators)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    final items = <ParsedItem>[];
    for (final segment in segments) {
      final item = _parseSegment(segment);
      if (item != null) items.add(item);
    }
    return items;
  }

  static ParsedItem? _parseSegment(String segment) {
    final tokens = segment.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;

    var quantity = 1.0;
    var start = 0;

    // Cantidad inicial: dígito o palabra de cantidad, si después viene el nombre
    // (no si lo que sigue es directamente un conector de precio).
    if (tokens.length > 1 && !_priceConnectors.contains(tokens[1])) {
      final digitQty = double.tryParse(tokens[0].replaceAll(',', '.'));
      if (digitQty != null) {
        quantity = digitQty;
        start = 1;
      } else if (_quantityWords.containsKey(tokens[0])) {
        quantity = _quantityWords[tokens[0]]!;
        start = 1;
      }
    }

    // Buscar el conector de precio (preferimos "de").
    int connectorIndex = -1;
    for (var i = start; i < tokens.length; i++) {
      if (tokens[i] == 'de') {
        connectorIndex = i;
        break;
      }
    }
    if (connectorIndex == -1) {
      for (var i = start; i < tokens.length; i++) {
        if (_priceConnectors.contains(tokens[i])) {
          connectorIndex = i;
          break;
        }
      }
    }

    String name;
    double? price;
    if (connectorIndex != -1) {
      name = tokens.sublist(start, connectorIndex).join(' ').trim();
      final priceTokens = tokens
          .sublist(connectorIndex + 1)
          .where((t) => t != 'pesos' && t != 'peso')
          .toList();
      price = parseNumber(priceTokens);
    } else {
      name = tokens.sublist(start).join(' ').trim();
    }

    if (name.isEmpty) return null;
    return ParsedItem(name: name, quantity: quantity, price: price);
  }
}
