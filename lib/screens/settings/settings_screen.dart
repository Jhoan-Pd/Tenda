import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/employees_provider.dart';
import '../../providers/settings_provider.dart';

/// Ajustes: nombre de la tienda, margen por defecto y API key de Grok.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _storeName;
  late final TextEditingController _margin;
  late final TextEditingController _apiKey;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _storeName = TextEditingController(text: settings.storeName);
    _margin = TextEditingController(
      text: settings.defaultMargin == settings.defaultMargin.roundToDouble()
          ? settings.defaultMargin.toInt().toString()
          : settings.defaultMargin.toString(),
    );
    _apiKey = TextEditingController(text: settings.grokApiKey);
  }

  @override
  void dispose() {
    _storeName.dispose();
    _margin.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    await settings.setStoreName(_storeName.text);
    final margin = double.tryParse(_margin.text.replaceAll(',', '.'));
    if (margin != null) await settings.setDefaultMargin(margin);
    await settings.setGrokApiKey(_apiKey.text);

    messenger.showSnackBar(const SnackBar(content: Text('Ajustes guardados')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Mi tienda', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _storeName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre de la tienda'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _margin,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Ganancia por defecto',
              suffixText: '%',
              helperText:
                  'Se usa al crear productos nuevos. Cada producto puede tener su propio %.',
            ),
          ),
          const SizedBox(height: 24),
          Text('Inteligencia artificial (Grok)', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Para escanear facturas con IA necesitas una API key de xAI. '
            'Se obtiene en console.x.ai (crea una cuenta, ve a "API Keys" y '
            'crea una nueva). Solo se guarda en tu teléfono.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKey,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'API key de Grok',
              hintText: 'xai-...',
              suffixIcon: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar ajustes'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Text('Responsables', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Las personas que atienden la tienda. Se eligen al fiar, al recibir '
            'abonos y al hacer recargas. No requieren contraseña.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 8),
          const _EmployeesSection(),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Tenda v1.0 — Hecho para tiendas de barrio 🇨🇴',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista de responsables con opción de agregar y eliminar.
class _EmployeesSection extends StatelessWidget {
  const _EmployeesSection();

  @override
  Widget build(BuildContext context) {
    final employees = context.watch<EmployeesProvider>();
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          for (final e in employees.employees)
            ListTile(
              leading: CircleAvatar(
                child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?'),
              ),
              title: Text(e.name),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                tooltip: 'Eliminar',
                onPressed: employees.employees.length <= 1
                    ? null
                    : () => employees.remove(e.id!),
              ),
            ),
          ListTile(
            leading: Icon(Icons.person_add_outlined, color: theme.colorScheme.primary),
            title: Text('Agregar responsable',
                style: TextStyle(color: theme.colorScheme.primary)),
            onTap: () => _add(context, employees),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, EmployeesProvider employees) async {
    final name = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo responsable'),
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await employees.add(name.text.trim());
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}
