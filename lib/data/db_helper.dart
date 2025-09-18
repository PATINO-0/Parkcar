// Comentarios en español.
// Helper de persistencia con dos backends:
// - SQLite (sqflite) en Android/iOS/Desktop -> relacional.
// - Sembast (IndexedDB) en Web -> fallback estable (no relacional).
//
// La API pública es la misma para toda la app.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;

// Alias para evitar conflicto de tipos Database
import 'package:sqflite/sqflite.dart' as sqf;
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast_web/sembast_web.dart';

import '../models/vehicle.dart';

class DBHelper {
  DBHelper._();
  static final DBHelper instance = DBHelper._();

  // SQLite (móvil/desktop)
  sqf.Database? _db;

  // Sembast (web)
  sembast.Database? _webDb;
  final sembast.StoreRef<int, Map<String, Object?>> _store =
      sembast.intMapStoreFactory.store('vehicles');

  // ---------- Inicialización ----------
  Future<sqf.Database> _openSqlite() async {
    if (_db != null) return _db!;
    final dbPath = await sqf.getDatabasesPath();
    final fullPath = p.join(dbPath, 'parkcar.db');
    _db = await sqf.openDatabase(
      fullPath,
      version: 2,
      onCreate: (db, v) async => _ensureSqliteSchema(db),
      onUpgrade: (db, o, n) async => _ensureSqliteSchema(db),
      onOpen: (db) async => _ensureSqliteSchema(db),
    );
    return _db!;
  }

  Future<void> _ensureSqliteSchema(sqf.Database db) async {
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

  Future<sembast.Database> _openWebDb() async {
    if (_webDb != null) return _webDb!;
    final factory = databaseFactoryWeb; // IndexedDB
    _webDb = await factory.openDatabase('parkcar_web.db');
    return _webDb!;
  }

  // ---------- Operaciones públicas ----------

  Future<int> insertVehicle(Vehicle vehicle) async {
    if (kIsWeb) {
      final db = await _openWebDb();
      // Enforce placa única
      final exists = await _store.findFirst(
        db,
        finder: sembast.Finder(
          filter: sembast.Filter.equals('plate', vehicle.plate),
        ),
      );
      if (exists != null) {
        throw Exception('UNIQUE constraint failed: vehicles.plate');
      }
      final key = await _store.add(db, {
        'plate': vehicle.plate,
        'type': vehicle.type,
        'entry_millis': vehicle.entryMillis,
      });
      // Guardar id opcionalmente como campo (no requerido)
      await _store.record(key).update(db, {'id': key});
      return key;
    } else {
      final db = await _openSqlite();
      return db.insert('vehicles', vehicle.toMap(),
          conflictAlgorithm: sqf.ConflictAlgorithm.abort);
    }
  }

  Future<List<Vehicle>> getActiveVehicles() async {
    if (kIsWeb) {
      final db = await _openWebDb();
      final snaps = await _store.find(
        db,
        finder: sembast.Finder(
          sortOrders: [sembast.SortOrder('entry_millis')],
        ),
      );
      return snaps.map((s) {
        final m = Map<String, dynamic>.from(s.value);
        return Vehicle(
          id: (m['id'] as int?) ?? s.key,
          plate: m['plate'] as String,
          type: m['type'] as String,
          entryMillis: m['entry_millis'] as int,
        );
      }).toList();
    } else {
      final db = await _openSqlite();
      final maps = await db.query('vehicles', orderBy: 'entry_millis ASC');
      return maps.map((e) => Vehicle.fromMap(e)).toList();
    }
  }

  Future<Vehicle?> getByPlate(String plate) async {
    if (kIsWeb) {
      final db = await _openWebDb();
      final snap = await _store.findFirst(
        db,
        finder:
            sembast.Finder(filter: sembast.Filter.equals('plate', plate)),
      );
      if (snap == null) return null;
      final m = Map<String, dynamic>.from(snap.value);
      return Vehicle(
        id: (m['id'] as int?) ?? snap.key,
        plate: m['plate'] as String,
        type: m['type'] as String,
        entryMillis: m['entry_millis'] as int,
      );
    } else {
      final db = await _openSqlite();
      final maps =
          await db.query('vehicles', where: 'plate = ?', whereArgs: [plate]);
      if (maps.isEmpty) return null;
      return Vehicle.fromMap(maps.first);
    }
  }

  Future<int> deleteById(int id) async {
    if (kIsWeb) {
      final db = await _openWebDb();
      await _store.record(id).delete(db);
      return 1;
    } else {
      final db = await _openSqlite();
      return db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<int> deleteByPlate(String plate) async {
    if (kIsWeb) {
      final db = await _openWebDb();
      final snap = await _store.findFirst(
        db,
        finder:
            sembast.Finder(filter: sembast.Filter.equals('plate', plate)),
      );
      if (snap == null) return 0;
      await _store.record(snap.key).delete(db);
      return 1;
    } else {
      final db = await _openSqlite();
      return db.delete('vehicles', where: 'plate = ?', whereArgs: [plate]);
    }
  }
}
