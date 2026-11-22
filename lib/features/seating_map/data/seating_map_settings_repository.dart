import 'package:flutter/widgets.dart';
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
  static const _imagePathKey = 'map_image_path';
  static const _imageWidthKey = 'map_image_width';
  static const _imageHeightKey = 'map_image_height';

  Future<String?> getImagePath() => getSetting(_imagePathKey);

  Future<void> saveImagePath(String? path) async {
    if (path == null) {
      await removeSetting(_imagePathKey);
    } else {
      await saveSetting(_imagePathKey, path);
    }
  }

  Future<Size> getImageSize({required double defaultWidth, required double defaultHeight}) async {
    final width = double.tryParse((await getSetting(_imageWidthKey)) ?? '');
    final height = double.tryParse((await getSetting(_imageHeightKey)) ?? '');
    if (width == null || height == null || width <= 0 || height <= 0) {
      return Size(defaultWidth, defaultHeight);
    }
    return Size(width, height);
  }

  Future<void> saveImageSize(Size size) async {
    await saveSetting(_imageWidthKey, '${size.width}');
    await saveSetting(_imageHeightKey, '${size.height}');
  }

  Future<String?> getSetting(String key) async {
    final db = await _databaseProvider.database;
    final rows = await db.query('app_settings', columns: ['setting_value'], where: 'setting_key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['setting_value'] as String?;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await _databaseProvider.database;
    await db.insert('app_settings', {'setting_key': key, 'setting_value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeSetting(String key) async {
    final db = await _databaseProvider.database;
    await db.delete('app_settings', where: 'setting_key = ?', whereArgs: [key]);
  }

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
