import 'package:flutter/widgets.dart';

/// 一個座位框的資料。
///
/// rect 使用 0～1 的正規化座標，與底圖實際像素尺寸無關。
/// SQLite 只保存四個邊界數值，讀取時再重建 Rect。
class SeatRegion {
  const SeatRegion({
    required this.name,
    required this.rect,
    required this.sortOrder,
    this.id,
    this.keywords = const [],
  });

  final int? id;
  final String name;
  final Rect rect;
  final int sortOrder;
  final List<String> keywords;

  SeatRegion copyWith({
    int? id,
    String? name,
    Rect? rect,
    int? sortOrder,
    List<String>? keywords,
  }) {
    return SeatRegion(
      id: id ?? this.id,
      name: name ?? this.name,
      rect: rect ?? this.rect,
      sortOrder: sortOrder ?? this.sortOrder,
      keywords: keywords ?? this.keywords,
    );
  }

  /// 用於 SQLite insert/update；自動遞增的 id 不放入 map。
  Map<String, Object?> toMap() {
    return {
      'name': name,
      'left_value': rect.left,
      'top_value': rect.top,
      'right_value': rect.right,
      'bottom_value': rect.bottom,
      'sort_order': sortOrder,
      'keywords': keywords.join(','),
    };
  }

  factory SeatRegion.fromMap(Map<String, Object?> map) {
    return SeatRegion(
      id: map['id'] as int,
      name: map['name'] as String,
      rect: Rect.fromLTRB(
        (map['left_value'] as num).toDouble(),
        (map['top_value'] as num).toDouble(),
        (map['right_value'] as num).toDouble(),
        (map['bottom_value'] as num).toDouble(),
      ),
      sortOrder: map['sort_order'] as int,
      keywords: (map['keywords'] as String? ?? '')
          .split(',')
          .map((keyword) => keyword.trim())
          .where((keyword) => keyword.isNotEmpty)
          .toList(growable: false),
    );
  }
}
