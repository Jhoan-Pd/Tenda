import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/sales_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/voice_parser.dart';

/// Venta por voz: el tendero dicta ("agua de 700, dos panes de 500") y la app
/// transcribe, interpreta y suma. La transcripción y cada renglón son editables.
class VoiceSaleScreen extends StatefulWidget {
  const VoiceSaleScreen({super.key});

  @override
  State<VoiceSaleScreen> createState() => _VoiceSaleScreenState();
}

/// Renglón resuelto: lo que se entendió + el producto del inventario (si lo hay).
class _ResolvedLine {
  String name;
  double quantity;
  double price;
  Product? product;

  _ResolvedLine({
    required this.name,
    required this.quantity,
    required this.price,
    this.product,
  });

  double get subtotal => quantity * price;
}

class _VoiceSaleScreenState extends State<VoiceSaleScreen> {
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _text = TextEditingController();

  bool _speechAvailable = false;
  bool _listening = false;
  String? _localeId;
  List<_ResolvedLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (mounted && (status == 'done' || status == 'notListening')) {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (_speechAvailable) {
        final locales = await _speech.locales();
        final spanish = locales.where((l) => l.localeId.toLowerCase().startsWith('es'));
        _localeId = spanish.isNotEmpty ? spanish.first.localeId : null;
      }
    } catch (_) {
      _speechAvailable = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleListen() async {
    if (!_speechAvailable) return;
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        setState(() => _text.text = result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        localeId: _localeId,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  void _interpret() {
    final inventory = context.read<InventoryProvider>();
    final parsed = VoiceParser.parse(_text.text);
    final lines = <_ResolvedLine>[];
    for (final item in parsed) {
      final product = inventory.matchByName(item.name);
      // Precio: el dictado manda; si no se dictó, usa el del inventario.
      final price = item.price ?? product?.price ?? 0;
      lines.add(_ResolvedLine(
        name: product?.name ?? item.name,
        quantity: item.quantity,
        price: price,
        product: product,
      ));
    }
    setState(() => _lines = lines);
  }

  double get _total => _lines.fold(0.0, (sum, l) => sum + l.subtotal);

  void _addAllToCart() {
    final sales = context.read<SalesProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    var added = 0;
    for (final l in _lines) {
      if (l.price <= 0) continue;
      sales.addResolvedItem(
        productId: l.product?.id ?? 0,
        name: l.name,
        quantity: l.quantity,
        unitPrice: l.price,
        unitCost: l.product?.cost ?? 0,
      );
      added++;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('$added producto${added == 1 ? '' : 's'} agregado${added == 1 ? '' : 's'} al carrito')),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Venta por voz')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _speechAvailable
                          ? 'Toca el micrófono y dicta, por ejemplo:\n'
                              '"agua de 700, dos panes de 500, una coca cola de 3000"'
                          : 'El micrófono no está disponible. Puedes escribir lo que '
                              'vendes en el cuadro de abajo (ej: "agua de 700, dos panes de 500").',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Semantics(
                    button: true,
                    label: _listening ? 'Detener dictado' : 'Empezar a dictar',
                    child: GestureDetector(
                      onTap: _speechAvailable ? _toggleListen : null,
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: _listening
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                        child: Icon(
                          _listening ? Icons.stop : Icons.mic,
                          size: 48,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _listening ? 'Escuchando... habla ahora' : 'Toca para dictar',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _text,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Lo que se vendió (puedes corregirlo)',
                    hintText: 'agua de 700, dos panes de 500',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _text.text.trim().isEmpty ? null : _interpret,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Interpretar lo dictado'),
                ),
                const SizedBox(height: 16),
                if (_lines.isNotEmpty) ...[
                  Text('Productos detectados', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Toca un renglón para corregirlo.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _lines.length; i++) _lineTile(i, theme),
                ],
              ],
            ),
          ),
          if (_lines.isNotEmpty)
            SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total', style: theme.textTheme.bodySmall),
                          Text(
                            Formatters.cop(_total),
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _total > 0 ? _addAllToCart : null,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Agregar al carrito'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _lineTile(int index, ThemeData theme) {
    final l = _lines[index];
    final unmatched = l.product == null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${l.quantity == l.quantity.roundToDouble() ? l.quantity.toInt() : l.quantity}'),
        ),
        title: Text(l.name),
        subtitle: Text(
          l.price > 0
              ? '${Formatters.cop(l.price)} c/u${unmatched ? ' · producto suelto' : ''}'
              : '⚠️ Falta el precio — tócalo para completarlo',
          style: TextStyle(
            color: l.price > 0 ? null : theme.colorScheme.error,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Formatters.cop(l.subtotal),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Quitar',
              onPressed: () => setState(() => _lines.removeAt(index)),
            ),
          ],
        ),
        onTap: () => _editLine(index),
      ),
    );
  }

  Future<void> _editLine(int index) async {
    final l = _lines[index];
    final name = TextEditingController(text: l.name);
    final qty = TextEditingController(
        text: l.quantity == l.quantity.roundToDouble()
            ? l.quantity.toInt().toString()
            : l.quantity.toString());
    final price = TextEditingController(
        text: l.price == l.price.roundToDouble() ? l.price.toInt().toString() : l.price.toString());

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Corregir producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Producto'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qty,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Precio', prefixText: r'$ '),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                l.name = name.text.trim().isEmpty ? l.name : name.text.trim();
                l.quantity = double.tryParse(qty.text.replaceAll(',', '.')) ?? l.quantity;
                l.price = double.tryParse(
                        price.text.replaceAll('.', '').replaceAll(',', '.')) ??
                    l.price;
                // Si cambió el nombre, intenta re-emparejar con el inventario.
                final match = context.read<InventoryProvider>().matchByName(l.name);
                l.product = match;
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
