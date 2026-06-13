/// Persona responsable que atiende la tienda (para fiados, recargas y cierres).
///
/// No hay inicio de sesión: simplemente se elige quién hizo el movimiento.
/// Por defecto vienen Ferney y Ana; se pueden agregar más en Ajustes.
class Employee {
  final int? id;
  final String name;

  Employee({this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory Employee.fromMap(Map<String, dynamic> map) => Employee(
        id: map['id'] as int?,
        name: map['name'] as String,
      );
}
