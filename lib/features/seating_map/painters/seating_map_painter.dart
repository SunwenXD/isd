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
  });

  final List<SeatRegion> regions;
  final Rect? draftRect;
  final int? selectedIndex;
  final int? highlightedIndex;
  final Size canvasSize;

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
  void _paintRegionName(Canvas canvas, Rect rect, String name) {
    const minFontSize = 8.0;
    const maxFontSize = 24.0;
    final padding = math.min(4.0, math.min(rect.width, rect.height) * 0.1);

    final vertical = rect.height > rect.width;
    final characters = name.runes.map(String.fromCharCode).toList();
    final availableWidth = math.max(0.0, rect.width - padding * 2);
    final availableHeight = math.max(0.0, rect.height - padding * 2);

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
          color: Colors.black,
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
    canvas.clipRect(rect.deflate(1));
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
