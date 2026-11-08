import 'package:flutter/material.dart';

import '../models/seat_region.dart';
import '../models/seating_map_types.dart';
import '../painters/seating_map_painter.dart';

class SeatingMapCanvas extends StatelessWidget {
  const SeatingMapCanvas({
    required this.mapWidth,
    required this.mapHeight,
    required this.transformationController,
    required this.mode,
    required this.regions,
    required this.draftRect,
    required this.selectedIndex,
    required this.highlightedIndex,
    required this.rotationQuarterTurns,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    super.key,
  });

  final double mapWidth;
  final double mapHeight;
  final TransformationController transformationController;
  final MapMode mode;
  final List<SeatRegion> regions;
  final Rect? draftRect;
  final int? selectedIndex;
  final int? highlightedIndex;
  final int rotationQuarterTurns;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

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

        return Container(
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: InteractiveViewer(
            transformationController: transformationController,
            constrained: false,
            panEnabled: mode == MapMode.browse,
            scaleEnabled: mode == MapMode.browse,
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
                    Image.asset(
                      'assets/images/seating_map.png',
                      fit: BoxFit.fill,
                    ),
                    CustomPaint(
                      painter: SeatingMapPainter(
                        regions: regions,
                        draftRect: draftRect,
                        selectedIndex: selectedIndex,
                        highlightedIndex: highlightedIndex,
                        canvasSize: Size(mapWidth, mapHeight),
                      ),
                    ),
                    if (mode != MapMode.browse)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: onPanStart,
                        onPanUpdate: onPanUpdate,
                        onPanEnd: onPanEnd,
                        child: const SizedBox.expand(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
