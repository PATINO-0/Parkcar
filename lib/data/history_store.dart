// Comentarios en español.
// Hive: almacena el histórico de cobros (no relacional).

import 'package:hive_flutter/hive_flutter.dart';

class HistoryStore {
  static const String boxName = 'history';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(boxName); // Box dinámico
  }

  static Box _box() => Hive.box(boxName);

  // Guarda un registro de salida
  static Future<void> addRecord({
    required String plate,
    required String type, // 'car' o 'moto'
    required DateTime entry,
    required DateTime exit,
    required int hours,
    required int total,
  }) async {
    final record = <String, dynamic>{
      'plate': plate,
      'type': type,
      'entryMillis': entry.millisecondsSinceEpoch,
      'exitMillis': exit.millisecondsSinceEpoch,
      'hours': hours,
      'total': total,
    };
    await _box().add(record);
  }

  static List<Map<String, dynamic>> getAll() {
    return _box()
        .values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> clearAll() async {
    await _box().clear();
  }
}
