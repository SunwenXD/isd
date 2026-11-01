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
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black12,
      child: InteractiveViewer(
        transformationController: transformationController,
        constrained: false,
        panEnabled: mode == MapMode.browse,
        scaleEnabled: mode == MapMode.browse,
        minScale: 0.5,
        maxScale: 5,
        boundaryMargin: const EdgeInsets.all(1000),
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
    );
  }
}
