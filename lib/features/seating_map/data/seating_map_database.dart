import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 管理 SQLite 連線與資料表版本。
///
/// 其他程式不要直接操作 SQL，統一透過 SeatRegionRepository。
class SeatingMapDatabase {
  SeatingMapDatabase._();

  static final SeatingMapDatabase instance = SeatingMapDatabase._();

  static const _databaseName = 'seating_map.db';
  static const _databaseVersion = 2;
  static const tableSeatRegions = 'seat_regions';

  Database? _database;

  Future<Database> get database async {
    final existingDatabase = _database;
    if (existingDatabase != null) return existingDatabase;

    final databasePath = await getDatabasesPath();
    final fullPath = p.join(databasePath, _databaseName);

    final openedDatabase = await openDatabase(
      fullPath,
      version: _databaseVersion,
      //創建sql
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableSeatRegions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL DEFAULT '',
            keywords TEXT NOT NULL DEFAULT '',
            left_value REAL NOT NULL,
            top_value REAL NOT NULL,
            right_value REAL NOT NULL,
            bottom_value REAL NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      //更新
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE $tableSeatRegions ADD COLUMN keywords TEXT NOT NULL DEFAULT ''",
          );
        }
      },
    );

    _database = openedDatabase;
    return openedDatabase;
  }
}
