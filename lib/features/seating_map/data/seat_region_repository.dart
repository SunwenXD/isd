import 'package:sqflite/sqflite.dart';

import '../models/seat_region.dart';
import 'seating_map_database.dart';

/// 座位框的資料存取層。
///
/// Page 只呼叫這裡的方法，不需要知道資料表名稱或 SQL 語法。
class SeatRegionRepository {
  SeatRegionRepository({
    SeatingMapDatabase? databaseProvider,
  }) : _databaseProvider =
            databaseProvider ?? SeatingMapDatabase.instance;

  final SeatingMapDatabase _databaseProvider;

  Future<List<SeatRegion>> getAll() async {
    final db = await _databaseProvider.database;
    final rows = await db.query(
      SeatingMapDatabase.tableSeatRegions,
      orderBy: 'sort_order ASC, id ASC',
    );

    return rows.map(SeatRegion.fromMap).toList(growable: false);
  }

  Future<SeatRegion> insert(SeatRegion region) async {
    final db = await _databaseProvider.database;
    final id = await db.insert(
      SeatingMapDatabase.tableSeatRegions,
      region.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return region.copyWith(id: id);
  }

  Future<void> update(SeatRegion region) async {
    final id = region.id;
    if (id == null) {
      throw ArgumentError('更新座位框前必須先取得資料庫 id。');
    }

    final db = await _databaseProvider.database;
    await db.update(
      SeatingMapDatabase.tableSeatRegions,
      region.toMap(),
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> delete(SeatRegion region) async {
    final id = region.id;
    if (id == null) {
      throw ArgumentError('刪除座位框前必須先取得資料庫 id。');
    }

    final db = await _databaseProvider.database;

    // 刪除與重新排序放在同一個 transaction，避免排序只更新一半。
    await db.transaction((txn) async {
      await txn.delete(
        SeatingMapDatabase.tableSeatRegions,
        where: 'id = ?',
        whereArgs: [id],
      );

      final rows = await txn.query(
        SeatingMapDatabase.tableSeatRegions,
        columns: ['id'],
        orderBy: 'sort_order ASC, id ASC',
      );

      for (var index = 0; index < rows.length; index++) {
        await txn.update(
          SeatingMapDatabase.tableSeatRegions,
          {'sort_order': index},
          where: 'id = ?',
          whereArgs: [rows[index]['id']],
        );
      }
    });
  }
}
