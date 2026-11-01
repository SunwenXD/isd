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
      if (name.isNotEmpty && rect.width >= 24 && rect.height >= 14) {
        final fontSize = math.min(
          24.0,
          math.min(
            rect.height * 0.45,
            rect.width / math.max(name.length, 1) * 1.6,
          ),
        ).clamp(8.0, 24.0).toDouble();

        final textPainter = TextPainter(
          text: TextSpan(
            text: name,
            style: TextStyle(
              color: Colors.black,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 1,
          ellipsis: '…',
        );

        textPainter.layout(maxWidth: math.max(0, rect.width - 8));

        canvas.save();
        canvas.clipRect(rect.deflate(2));
        textPainter.paint(
          canvas,
          Offset(
            rect.center.dx - textPainter.width / 2,
            rect.center.dy - textPainter.height / 2,
          ),
        );
        canvas.restore();
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

  @override
  bool shouldRepaint(covariant SeatingMapPainter oldDelegate) {
    // regions 會在拖曳時原地更新，直接重繪可避免參考相同而漏更新。
    return true;
  }
}
