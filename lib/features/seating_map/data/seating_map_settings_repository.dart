import 'package:sqflite/sqflite.dart';

import 'seating_map_database.dart';

/// 負責保存座位地圖本身的設定，例如底圖旋轉方向。
class SeatingMapSettingsRepository {
  SeatingMapSettingsRepository({
    SeatingMapDatabase? databaseProvider,
  }) : _databaseProvider =
            databaseProvider ?? SeatingMapDatabase.instance;

  final SeatingMapDatabase _databaseProvider;
  static const _rotationKey = 'map_rotation_quarter_turns';

  /// 回傳順時針旋轉的 90 度倍數，預設為 0 度。
  Future<int> getRotationQuarterTurns() async {
    final db = await _databaseProvider.database;
    final rows = await db.query(
      'app_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [_rotationKey],
      limit: 1,
    );

    if (rows.isEmpty) return 0;
    final value = int.tryParse(rows.first['setting_value'] as String? ?? '');
    if (value == null) return 0;
    return value % 4;
  }

  /// 保存 0、1、2、3，分別代表順時針 0、90、180、270 度。
  Future<void> saveRotationQuarterTurns(int quarterTurns) async {
    final db = await _databaseProvider.database;
    await db.insert(
      'app_settings',
      {
        'setting_key': _rotationKey,
        'setting_value': '${quarterTurns % 4}',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
