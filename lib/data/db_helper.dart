// Comentarios en español.
// Helper para SQLite: maneja la tabla de vehículos activos.
// Incluye soporte Web con sqflite_common_ffi_web y recarga de esquema segura.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../models/vehicle.dart';

class DBHelper {
  DBHelper._();
  static final DBHelper instance = DBHelper._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    if (kIsWeb) {
      // En Web: usar la fábrica FFI web (SQLite en IndexedDB via WASM).
      databaseFactory = databaseFactoryFfiWeb;
      _db = await databaseFactory.openDatabase(
        'parkcar.db',
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, v) async => _ensureSchema(db),
          onUpgrade: (db, o, n) async => _ensureSchema(db),
          onOpen: (db) async => _ensureSchema(db),
        ),
      );
      return _db!;
    }

    // En móvil/desktop: ruta de archivos nativa.
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, 'parkcar.db');
    _db = await openDatabase(
      fullPath,
      version: 2, // versión subida para forzar upgrade si existe DB previa
      onCreate: (db, version) async => _ensureSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async => _ensureSchema(db),
      onOpen: (db) async => _ensureSchema(db),
    );
    return _db!;
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vehicles(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plate TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL CHECK(type IN ('car','moto')),
        entry_millis INTEGER NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_plate ON vehicles(plate);');
  }

  Future<int> insertVehicle(Vehicle vehicle) async {
    final db = await database;
    return db.insert('vehicles', vehicle.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<List<Vehicle>> getActiveVehicles() async {
    final db = await database;
    final maps = await db.query('vehicles', orderBy: 'entry_millis ASC');
    return maps.map((e) => Vehicle.fromMap(e)).toList();
  }

  Future<Vehicle?> getByPlate(String plate) async {
    final db = await database;
    final maps =
        await db.query('vehicles', where: 'plate = ?', whereArgs: [plate]);
    if (maps.isEmpty) return null;
    return Vehicle.fromMap(maps.first);
  }

  Future<int> deleteById(int id) async {
    final db = await database;
    return db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteByPlate(String plate) async {
    final db = await database;
    return db.delete('vehicles', where: 'plate = ?', whereArgs: [plate]);
  }
}
