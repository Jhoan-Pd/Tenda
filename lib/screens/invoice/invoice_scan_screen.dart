import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/grok_service.dart';
import '../settings/settings_screen.dart';
import 'invoice_review_screen.dart';

/// Escanea la factura del proveedor con la cámara y usa la IA de Grok
/// para extraer los productos, cantidades y costos unitarios.
class InvoiceScanScreen extends StatefulWidget {
  const InvoiceScanScreen({super.key});

  @override
  State<InvoiceScanScreen> createState() => _InvoiceScanScreenState();
}

class _InvoiceScanScreenState extends State<InvoiceScanScreen> {
  final _picker = ImagePicker();
  File? _image;
  bool _processing = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _error = null;
    });
  }

  Future<void> _analyze() async {
    final image = _image;
    if (image == null || _processing) return;

    final settings = context.read<SettingsProvider>();
    final navigator = Navigator.of(context);

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final service = GrokService(settings.grokApiKey);
      final items = await service.extractInvoiceItems(
        image,
        defaultMargin: settings.defaultMargin,
      );
      if (!mounted) return;
      setState(() => _processing = false);
      navigator.push(
        MaterialPageRoute(builder: (_) => InvoiceReviewScreen(items: items)),
      );
    } on GrokException catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'Error inesperado: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Escanear factura')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!settings.hasGrokKey)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('Falta la API key de Grok'),
                subtitle: const Text(
                  'Configúrala en Ajustes para poder leer facturas con IA. '
                  'Se obtiene gratis en console.x.ai',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: _image == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 72, color: theme.colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          'Toma una foto clara de la factura\ndel proveedor',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    )
                  : Image.file(_image!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Cámara'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galería'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_image != null && !_processing) ? _analyze : null,
            icon: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_processing ? 'Leyendo factura con IA...' : 'Extraer productos con IA'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Consejos para una buena lectura:\n'
            '• Buena iluminación, sin sombras.\n'
            '• La factura completa dentro de la foto.\n'
            '• Evita arrugas y reflejos.\n'
            '• Después podrás revisar y corregir lo que la IA detecte.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
