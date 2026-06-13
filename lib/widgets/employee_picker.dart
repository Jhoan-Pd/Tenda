import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/employee.dart';
import '../providers/employees_provider.dart';

/// Muestra un selector de responsable (Ferney, Ana, ...) y permite agregar
/// uno nuevo en el momento. Devuelve el [Employee] elegido o null si se cancela.
Future<Employee?> pickEmployee(
  BuildContext context, {
  String title = '¿Quién es el responsable?',
}) {
  final employees = context.read<EmployeesProvider>();
  return showModalBottomSheet<Employee>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final e in employees.employees)
                  ListTile(
                    leading: CircleAvatar(
                      child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?'),
                    ),
                    title: Text(e.name, style: const TextStyle(fontSize: 17)),
                    onTap: () => Navigator.pop(sheetContext, e),
                  ),
                ListTile(
                  leading: Icon(Icons.person_add_outlined,
                      color: Theme.of(sheetContext).colorScheme.primary),
                  title: Text(
                    'Agregar responsable',
                    style: TextStyle(color: Theme.of(sheetContext).colorScheme.primary),
                  ),
                  onTap: () async {
                    final created = await _addEmployeeDialog(sheetContext, employees);
                    if (created != null && sheetContext.mounted) {
                      Navigator.pop(sheetContext, created);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<Employee?> _addEmployeeDialog(
  BuildContext context,
  EmployeesProvider employees,
) {
  final name = TextEditingController();
  return showDialog<Employee>(
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
            final created = await employees.add(name.text.trim());
            if (dialogContext.mounted) Navigator.pop(dialogContext, created);
          },
          child: const Text('Agregar'),
        ),
      ],
    ),
  );
}
