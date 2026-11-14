import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/seat_region.dart';

class SeatingMapPainter extends CustomPainter {
  const SeatingMapPainter({
    required this.regions,
    required this.draftRect,
    required this.selectedIndex,
    required this.highlightedIndex,
    required this.canvasSize,
    required this.rotationQuarterTurns,
    required this.showAllRegions,
  });

  final List<SeatRegion> regions;
  final Rect? draftRect;
  final int? selectedIndex;
  final int? highlightedIndex;
  final Size canvasSize;
  final int rotationQuarterTurns;
  final bool showAllRegions;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.amber.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final selectedPaint = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    final highlightedFillPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.28)
      ..style = PaintingStyle.fill;

    final highlightedBorderPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;

    final draftPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    Rect toCanvasRect(Rect rect) {
      return Rect.fromLTRB(
        rect.left * canvasSize.width,
        rect.top * canvasSize.height,
        rect.right * canvasSize.width,
        rect.bottom * canvasSize.height,
      );
    }

    for (var index = 0; index < regions.length; index++) {
      final rect = toCanvasRect(regions[index].rect);

      // 查詢模式只顯示文字，不繪製矩形底色、外框或控制點。
      // 所有區域名稱仍可辨識，搜尋命中的名稱改用醒目顏色。
      if (!showAllRegions) {
        final name = regions[index].name.trim();
        if (name.isNotEmpty && rect.width > 0 && rect.height > 0) {
          _paintRegionName(
            canvas,
            rect,
            name,
            color: index == highlightedIndex
                ? Colors.cyanAccent
                : Colors.black,
          );
        }
        continue;
      }

      canvas.drawRect(rect, fillPaint);
      if (index == highlightedIndex) {
        canvas.drawRect(rect, highlightedFillPaint);
      }
      canvas.drawRect(
        rect,
        index == highlightedIndex
            ? highlightedBorderPaint
            : index == selectedIndex
                ? selectedPaint
                : borderPaint,
      );

      final name = regions[index].name.trim();
      if (name.isNotEmpty && rect.width > 0 && rect.height > 0) {
        _paintRegionName(canvas, rect, name);
      }

      if (index == selectedIndex) {
        for (final point in [
          rect.topLeft,
          rect.topRight,
          rect.bottomLeft,
          rect.bottomRight,
        ]) {
          canvas.drawCircle(
            point,
            9,
            Paint()..color = Colors.white,
          );
          canvas.drawCircle(
            point,
            9,
            Paint()
              ..color = Colors.blue
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          );
        }
      }
    }

    if (draftRect != null) {
      canvas.drawRect(toCanvasRect(draftRect!), draftPaint);
    }
  }

  /// 依座位框長寬決定文字方向，並盡可能將文字縮放至框內。
  /// 當完整名稱需要的字體小於最小字級時，只顯示第一個字。
  void _paintRegionName(
    Canvas canvas,
    Rect rect,
    String name, {
    Color color = Colors.black,
  }) {
    const minFontSize = 8.0;
    const maxFontSize = 24.0;
    final padding = math.min(4.0, math.min(rect.width, rect.height) * 0.1);

    final isQuarterTurn = rotationQuarterTurns.isOdd;
    final displayWidth = isQuarterTurn ? rect.height : rect.width;
    final displayHeight = isQuarterTurn ? rect.width : rect.height;
    final vertical = displayHeight > displayWidth;
    final characters = name.runes.map(String.fromCharCode).toList();
    final availableWidth = math.max(0.0, displayWidth - padding * 2);
    final availableHeight = math.max(0.0, displayHeight - padding * 2);

    if (availableWidth <= 0 || availableHeight <= 0) return;

    final fullText = vertical ? characters.join('\n') : name;
    final estimatedSize = vertical
        ? math.min(availableWidth, availableHeight / characters.length)
        : math.min(availableHeight, availableWidth / math.max(characters.length, 1));
    final fontSize = math.min(maxFontSize, estimatedSize).toDouble();
    final displayText = fontSize < minFontSize && characters.isNotEmpty
        ? characters.first
        : fullText;
    final displayFontSize = fontSize < minFontSize ? minFontSize : fontSize;

    final textPainter = TextPainter(
      text: TextSpan(
        text: displayText,
        style: TextStyle(
          color: color,
          fontSize: displayFontSize,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: vertical ? characters.length : 1,
      ellipsis: null,
    )..layout(maxWidth: availableWidth);

    canvas.save();
    // RotatedBox 會連同整個 CustomPaint 一起旋轉；在每個文字中心反向旋轉，
    // 讓文字在畫面上維持水平正向，而文字中心仍跟著座位框移動。
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(-rotationQuarterTurns * math.pi / 2);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    canvas.clipRect(Rect.fromCenter(
      center: rect.center,
      width: displayWidth,
      height: displayHeight,
    ).deflate(1));
    textPainter.paint(
      canvas,
      Offset(
        rect.center.dx - textPainter.width / 2,
        rect.center.dy - textPainter.height / 2,
      ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SeatingMapPainter oldDelegate) {
    // regions 會在拖曳時原地更新，直接重繪可避免參考相同而漏更新。
    return true;
  }
}
