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


  /// 以姓名或任一關鍵字進行部分文字比對。
  /// 空白查詢回傳空清單；查詢字串可只包含一個字。
  Future<List<SeatRegion>> search(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];

    final regions = await getAll();
    final needle = normalizedQuery.toLowerCase();
    return regions.where((region) {
      final searchableValues = [region.name, ...region.keywords];
      return searchableValues.any(
        (value) => value.toLowerCase().contains(needle),
      );
    }).toList(growable: false);
  }

  /// 以 transaction 一次替換所有座位框，避免匯入中斷造成資料不完整。
  Future<void> replaceAll(List<SeatRegion> regions) async {
    final db = await _databaseProvider.database;
    await db.transaction((txn) async {
      await txn.delete(SeatingMapDatabase.tableSeatRegions);
      for (var index = 0; index < regions.length; index++) {
        await txn.insert(
          SeatingMapDatabase.tableSeatRegions,
          regions[index].copyWith(sortOrder: index).toMap(),
        );
      }
    });
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
