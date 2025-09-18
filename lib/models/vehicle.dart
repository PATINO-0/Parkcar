// Comentarios en español.
// Modelo simple para representar un vehículo activo en el parqueadero.

class Vehicle {
  final int? id;
  final String plate;
  final String type; // 'car' o 'moto'
  final int entryMillis; // epoch ms de la hora de entrada

  Vehicle({
    this.id,
    required this.plate,
    required this.type,
    required this.entryMillis,
  });

  factory Vehicle.fromMap(Map<String, dynamic> map) => Vehicle(
        id: map['id'] as int?,
        plate: map['plate'] as String,
        type: map['type'] as String,
        entryMillis: map['entry_millis'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'plate': plate,
        'type': type,
        'entry_millis': entryMillis,
      };
}
