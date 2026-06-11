import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/invoice_item.dart';

/// Excepción legible para mostrar al usuario cuando falla la lectura con IA.
class GrokException implements Exception {
  final String message;
  GrokException(this.message);

  @override
  String toString() => message;
}

/// Cliente de la API de Grok (xAI) para extraer productos de la foto
/// de una factura de proveedor.
///
/// La API key se obtiene gratis registrándose en https://console.x.ai
/// y se configura dentro de la app en Ajustes.
class GrokService {
  static const _endpoint = 'https://api.x.ai/v1/chat/completions';
  static const _model = 'grok-2-vision-1212';

  final String apiKey;

  GrokService(this.apiKey);

  static const _prompt = '''
Eres un asistente que lee facturas de proveedores de tiendas en Colombia.
Analiza la imagen de la factura y extrae TODOS los productos que aparecen.
Responde ÚNICAMENTE con un JSON válido, sin explicaciones ni markdown, con esta estructura:
{"items":[{"nombre":"...","cantidad":1,"precio_unitario":0,"precio_total":0}]}
Reglas:
- "cantidad" es el número de unidades compradas.
- "precio_unitario" es el costo por unidad en pesos colombianos (sin puntos ni símbolos).
- Si solo aparece el total del renglón, ponlo en "precio_total" y deja "precio_unitario" en 0.
- Usa nombres de producto claros y cortos (ej: "Arroz Diana 500g").
- No incluyas el IVA total, fletes ni descuentos como productos.
''';

  /// Envía la foto de la factura y devuelve los productos detectados.
  Future<List<InvoiceItem>> extractInvoiceItems(
    File image, {
    double defaultMargin = 20,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw GrokException(
        'Configura tu API key de Grok en Ajustes para usar el escáner de facturas.',
      );
    }

    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final body = jsonEncode({
      'model': _model,
      'temperature': 0,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
            },
            {'type': 'text', 'text': _prompt},
          ],
        },
      ],
    });

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${apiKey.trim()}',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 90));
    } on SocketException {
      throw GrokException('Sin conexión a internet. El escáner de facturas necesita internet.');
    } catch (e) {
      throw GrokException('No se pudo conectar con Grok: $e');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw GrokException('API key de Grok inválida. Revísala en Ajustes.');
    }
    if (response.statusCode != 200) {
      throw GrokException('Error de Grok (${response.statusCode}). Intenta de nuevo.');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final content =
        decoded['choices']?[0]?['message']?['content'] as String? ?? '';
    return _parseItems(content, defaultMargin);
  }

  /// Extrae el JSON de la respuesta del modelo (tolera fences de markdown).
  List<InvoiceItem> _parseItems(String content, double defaultMargin) {
    var text = content.trim();
    if (text.startsWith('```')) {
      text = text.replaceAll(RegExp(r'^```[a-zA-Z]*\n?'), '').replaceAll(RegExp(r'```$'), '').trim();
    }
    // Por si el modelo agrega texto alrededor, ubicamos el primer objeto JSON.
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw GrokException('La IA no encontró productos en la imagen. Toma una foto más clara.');
    }

    dynamic parsed;
    try {
      parsed = jsonDecode(text.substring(start, end + 1));
    } on FormatException {
      throw GrokException('No se pudo interpretar la respuesta de la IA. Intenta de nuevo.');
    }

    final items = (parsed['items'] as List?) ?? [];
    final result = items
        .whereType<Map<String, dynamic>>()
        .map((e) => InvoiceItem.fromJson(e, defaultMargin: defaultMargin))
        .where((item) => item.name.isNotEmpty)
        .toList();

    if (result.isEmpty) {
      throw GrokException('No se detectaron productos en la factura. Toma una foto más clara.');
    }
    return result;
  }
}
