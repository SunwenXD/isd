import 'dart:io';

import 'package:flutter/material.dart';

import '../models/seat_region.dart';
import '../models/seating_map_types.dart';
import '../painters/seating_map_painter.dart';

class SeatingMapCanvas extends StatelessWidget {
  const SeatingMapCanvas({
    required this.mapWidth,
    required this.mapHeight,
    required this.imagePath,
    required this.transformationController,
    required this.mode,
    required this.regions,
    required this.draftRect,
    required this.selectedIndex,
    required this.highlightedIndex,
    required this.rotationQuarterTurns,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    super.key,
  });

  final double mapWidth;
  final double mapHeight;
  final String? imagePath;
  final TransformationController transformationController;
  final MapMode mode;
  final List<SeatRegion> regions;
  final Rect? draftRect;
  final int? selectedIndex;
  final int? highlightedIndex;
  final int rotationQuarterTurns;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final ValueChanged<PointerMoveEvent> onPointerMove;
  final ValueChanged<PointerEvent> onPointerUp;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 最小縮放比例至少要讓底圖覆蓋可視區域，避免拖曳時露出灰色空白。
        final isQuarterTurn = rotationQuarterTurns.isOdd;
        final displayedWidth = isQuarterTurn ? mapHeight : mapWidth;
        final displayedHeight = isQuarterTurn ? mapWidth : mapHeight;
        final minScale = <double>[
          0.1,
          constraints.maxWidth / displayedWidth,
          constraints.maxHeight / displayedHeight,
        ].reduce((a, b) => a > b ? a : b).clamp(0.1, 5.0).toDouble();

        return ClipRect(
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: InteractiveViewer(
              transformationController: transformationController,
              constrained: false,
              // 編輯模式由單指原始指標事件處理框與底圖拖曳；
              // InteractiveViewer 保留雙指縮放辨識，避免 GestureDetector 的 onPan 搶走手勢。
              panEnabled: mode == MapMode.browse,
              scaleEnabled: true,
              minScale: minScale,
              maxScale: 5,
              boundaryMargin: EdgeInsets.zero,
              clipBehavior: Clip.hardEdge,
              child: RotatedBox(
                quarterTurns: rotationQuarterTurns,
                child: SizedBox(
                  width: mapWidth,
                  height: mapHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imagePath == null)
                        Image.asset(
                          'assets/images/seating_map.png',
                          fit: BoxFit.fill,
                        )
                      else
                        Image.file(
                          File(imagePath!),
                          fit: BoxFit.fill,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(
                            color: Colors.black12,
                            child: Center(child: Text('地圖圖片載入失敗')),
                          ),
                        ),
                      CustomPaint(
                        painter: SeatingMapPainter(
                          regions: regions,
                          draftRect: draftRect,
                          selectedIndex: selectedIndex,
                          highlightedIndex: highlightedIndex,
                          canvasSize: Size(mapWidth, mapHeight),
                          rotationQuarterTurns: rotationQuarterTurns,
                          showAllRegions: mode != MapMode.browse,
                        ),
                      ),
                      if (mode != MapMode.browse)
                        Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: onPointerDown,
                          onPointerMove: onPointerMove,
                          onPointerUp: onPointerUp,
                          onPointerCancel: onPointerUp,
                          child: const SizedBox.expand(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
