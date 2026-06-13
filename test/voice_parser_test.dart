import 'package:flutter_test/flutter_test.dart';
import 'package:tenda/utils/voice_parser.dart';

void main() {
  group('VoiceParser.parseNumber', () {
    test('números en dígitos', () {
      expect(VoiceParser.parseNumber(['700']), 700);
      expect(VoiceParser.parseNumber(['1500']), 1500);
    });

    test('números en palabras', () {
      expect(VoiceParser.parseNumber(['setecientos']), 700);
      expect(VoiceParser.parseNumber(['mil']), 1000);
      expect(VoiceParser.parseNumber(['mil', 'quinientos']), 1500);
      expect(VoiceParser.parseNumber(['dos', 'mil']), 2000);
      expect(VoiceParser.parseNumber(['tres', 'mil', 'quinientos']), 3500);
      expect(VoiceParser.parseNumber(['ciento', 'cincuenta']), 150);
    });

    test('texto sin número devuelve null', () {
      expect(VoiceParser.parseNumber(['agua']), isNull);
    });
  });

  group('VoiceParser.parse (vocabulario de tienda)', () {
    test('"agua de 700" -> 1 agua a 700', () {
      final items = VoiceParser.parse('agua de 700');
      expect(items.length, 1);
      expect(items.first.name, 'agua');
      expect(items.first.quantity, 1);
      expect(items.first.price, 700);
    });

    test('cantidad en palabras: "dos panes de 500"', () {
      final items = VoiceParser.parse('dos panes de 500');
      expect(items.length, 1);
      expect(items.first.quantity, 2);
      expect(items.first.name, 'panes');
      expect(items.first.price, 500);
    });

    test('varios productos separados por coma', () {
      final items = VoiceParser.parse('una coca cola de 3000, agua de 700');
      expect(items.length, 2);
      expect(items[0].name, 'coca cola');
      expect(items[0].price, 3000);
      expect(items[1].name, 'agua');
      expect(items[1].price, 700);
    });

    test('precio dictado en palabras', () {
      final items = VoiceParser.parse('tres aguas de setecientos');
      expect(items.first.quantity, 3);
      expect(items.first.price, 700);
    });

    test('precio con punto de miles no rompe el producto', () {
      final items = VoiceParser.parse('arroz de 1.500');
      expect(items.length, 1);
      expect(items.first.name, 'arroz');
      expect(items.first.price, 1500);
    });

    test('sin precio deja price en null para buscar en inventario', () {
      final items = VoiceParser.parse('pan');
      expect(items.length, 1);
      expect(items.first.name, 'pan');
      expect(items.first.price, isNull);
    });

    test('separador "y" entre productos', () {
      final items = VoiceParser.parse('agua de 700 y gaseosa de 2000');
      expect(items.length, 2);
      expect(items[1].name, 'gaseosa');
      expect(items[1].price, 2000);
    });
  });
}
