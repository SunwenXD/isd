import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MapMode {
  browse,
  draw,
  edit,
}

enum ResizeHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class SeatingMapPage extends StatefulWidget {
  const SeatingMapPage({super.key});

  @override
  State<SeatingMapPage> createState() => _SeatingMapPageState();
}

class _SeatingMapPageState extends State<SeatingMapPage> {

  // 底圖採用固定的邏輯座標系統。
  static const double mapWidth = 1086;
  static const double mapHeight = 1448;

  // 四角控制點的點選範圍，以底圖座標計算。
  static const double handleHitRadius = 30;

  // 避免矩形縮小到無法選取。
  static const double minRectSize = 0.005;

  final TransformationController _transformationController =
  TransformationController();

  //模式
  MapMode _mode = MapMode.browse;


  // 框選資料使用 0～1 的相對座標。
  // 例如 left = 0.2，代表矩形左邊位於圖片寬度的 20%。
  final List<Rect> _rects = [];

  int? _selectedIndex;

  Offset? _gestureStart;
  Rect? _draftRect;
  Rect? _initialRect;
  ResizeHandle? _activeHandle;



  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  double _clamp(double value, double min, double max) {
    return value.clamp(min, max).toDouble();
  }

  // 將圖片上的邏輯座標轉成相對座標。
  Offset _normalizePoint(Offset point) {
    return Offset(
      _clamp(point.dx / mapWidth, 0, 1),
      _clamp(point.dy / mapHeight, 0, 1),
    );
  }

  Rect _makeRect(Offset a, Offset b) {
    return Rect.fromLTRB(
      _clamp(math.min(a.dx, b.dx), 0, 1),
      _clamp(math.min(a.dy, b.dy), 0, 1),
      _clamp(math.max(a.dx, b.dx), 0, 1),
      _clamp(math.max(a.dy, b.dy), 0, 1),
    );
  }

  Offset _toImagePoint(Offset normalized) {
    return Offset(
      normalized.dx * mapWidth,
      normalized.dy * mapHeight,
    );
  }

  // 找出使用者按下的位置是否命中矩形角落。
  ResizeHandle? _findHandle(
      Rect rect,
      Offset point,
      ) {
    final corners = <ResizeHandle, Offset>{
      ResizeHandle.topLeft:
      Offset(rect.left, rect.top),
      ResizeHandle.topRight:
      Offset(rect.right, rect.top),
      ResizeHandle.bottomLeft:
      Offset(rect.left, rect.bottom),
      ResizeHandle.bottomRight:
      Offset(rect.right, rect.bottom),
    };

    final imagePoint = _toImagePoint(point);

    for (final entry in corners.entries) {
      final corner = _toImagePoint(entry.value);

      if ((imagePoint - corner).distance <= handleHitRadius) {
        return entry.key;
      }
    }

    return null;
  }

  // 從最上層矩形開始測試命中。
  int? _findRect(Offset point) {
    for (int i = _rects.length - 1; i >= 0; i--) {
      if (_rects[i].contains(point)) {
        return i;
      }
    }

    return null;
  }

  void _onPanStart(DragStartDetails details) {
    final point = _normalizePoint(details.localPosition);

    setState(() {
      _gestureStart = point;
      _activeHandle = null;
      _initialRect = null;

      if (_mode == MapMode.draw) {
        _draftRect = Rect.fromPoints(point, point);
        return;
      }

      if (_mode == MapMode.edit) {
        // 已選取矩形的角落優先判定，
        // 避免角落手柄被矩形本身攔截。
        if (_selectedIndex != null) {
          final selectedRect = _rects[_selectedIndex!];
          final handle = _findHandle(selectedRect, point);

          if (handle != null) {
            _activeHandle = handle;
            _initialRect = selectedRect;
            return;
          }
        }

        final index = _findRect(point);
        _selectedIndex = index;

        if (index != null) {
          _initialRect = _rects[index];
        }
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_gestureStart == null) return;

    final point = _normalizePoint(details.localPosition);

    setState(() {
      if (_mode == MapMode.draw) {
        _draftRect = _makeRect(_gestureStart!, point);
        return;
      }

      if (_mode != MapMode.edit ||
          _selectedIndex == null ||
          _initialRect == null) {
        return;
      }

      final dx = point.dx - _gestureStart!.dx;
      final dy = point.dy - _gestureStart!.dy;
      final initial = _initialRect!;

      if (_activeHandle == null) {
        // 移動矩形：保持寬高不變，避免超出底圖。
        final left = _clamp(
          initial.left + dx,
          0,
          1 - initial.width,
        );
        final top = _clamp(
          initial.top + dy,
          0,
          1 - initial.height,
        );

        _rects[_selectedIndex!] = Rect.fromLTWH(
          left,
          top,
          initial.width,
          initial.height,
        );
      } else {
        // 調整指定角落，其他角落保持固定。
        double left = initial.left;
        double top = initial.top;
        double right = initial.right;
        double bottom = initial.bottom;

        switch (_activeHandle!) {
          case ResizeHandle.topLeft:
            left = _clamp(
              initial.left + dx,
              0,
              right - minRectSize,
            );
            top = _clamp(
              initial.top + dy,
              0,
              bottom - minRectSize,
            );

          case ResizeHandle.topRight:
            right = _clamp(
              initial.right + dx,
              left + minRectSize,
              1,
            );
            top = _clamp(
              initial.top + dy,
              0,
              bottom - minRectSize,
            );

          case ResizeHandle.bottomLeft:
            left = _clamp(
              initial.left + dx,
              0,
              right - minRectSize,
            );
            bottom = _clamp(
              initial.bottom + dy,
              top + minRectSize,
              1,
            );

          case ResizeHandle.bottomRight:
            right = _clamp(
              initial.right + dx,
              left + minRectSize,
              1,
            );
            bottom = _clamp(
              initial.bottom + dy,
              top + minRectSize,
              1,
            );
        }

        _rects[_selectedIndex!] = Rect.fromLTRB(
          left,
          top,
          right,
          bottom,
        );
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      if (_mode == MapMode.draw) {
        final rect = _draftRect;

        if (rect != null &&
            rect.width >= minRectSize &&
            rect.height >= minRectSize) {
          _rects.add(rect);
          _selectedIndex = _rects.length - 1;
        }
      }

      _gestureStart = null;
      _draftRect = null;
      _initialRect = null;
      _activeHandle = null;
    });
  }

  void _changeMode(MapMode mode) {
    setState(() {
      _mode = mode;
      _gestureStart = null;
      _draftRect = null;
      _initialRect = null;
      _activeHandle = null;
    });
  }

  void _deleteSelected() {
    if (_selectedIndex == null) return;

    setState(() {
      _rects.removeAt(_selectedIndex!);
      _selectedIndex = null;
    });
  }

  void _resetView() {
    _transformationController.value = Matrix4.identity();
  }

  String _percent(double value) =>
      '${(value * 100).toStringAsFixed(2)}%';

  String _formatRect(Rect rect) {
    return 'X ${_percent(rect.left)}  '
        'Y ${_percent(rect.top)}\n'
        'W ${_percent(rect.width)}  '
        'H ${_percent(rect.height)}';
  }

  String _formatPixels(Rect rect) {
    final left = (rect.left * mapWidth).round();
    final top = (rect.top * mapHeight).round();
    final width = (rect.width * mapWidth).round();
    final height = (rect.height * mapHeight).round();

    return '像素座標：X=$left, Y=$top, '
        'W=$width, H=$height';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('座位表編輯器'),
        actions: [
          IconButton(
            tooltip: '重設圖片視角',
            onPressed: _resetView,
            icon: const Icon(Icons.center_focus_strong),
          ),
        ],
      ),
      body: Column(
          children: [
            _buildToolbar(),
            Expanded(child: Container(
              color: Colors.black12,
              child: InteractiveViewer(
                  transformationController: _transformationController,
                  constrained: false,
                  panEnabled: _mode == MapMode.browse,
                  scaleEnabled: _mode == MapMode.browse,
                  minScale: 0.5,
                  maxScale: 5.0,
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
                          // 顯示已完成的框與目前拖曳中的預覽框。
                          CustomPaint(
                            painter: _SelectionPainter(
                              rects: _rects,
                              draftRect: _draftRect,
                              selectedIndex: _selectedIndex,
                              canvasSize: const Size(
                                mapWidth,
                                mapHeight,
                              ),
                            ),
                          ),
                          // 只有框選模式才接收拖曳手勢。
                          if (_mode != MapMode.browse)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: _onPanStart,
                              onPanUpdate: _onPanUpdate,
                              onPanEnd: _onPanEnd,
                              child: const SizedBox.expand(),
                            ),
                        ]
                    ),
                  )

              ),
            )),
            _buildSelectionList(),
          ]
      ),

    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SegmentedButton<MapMode>(
            segments: const [
              ButtonSegment(
                value: MapMode.browse,
                icon: Icon(Icons.pan_tool_alt),
                label: Text('瀏覽'),
              ),
              ButtonSegment(
                value: MapMode.draw,
                icon: Icon(Icons.crop_free),
                label: Text('新增框'),
              ),
              ButtonSegment(
                value: MapMode.edit,
                icon: Icon(Icons.open_with),
                label: Text('調整框'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) {
              _changeMode(selection.first);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  switch (_mode) {
                    MapMode.browse => '拖曳與縮放底圖',
                    MapMode.draw => '在圖片上拖曳建立矩形',
                    MapMode.edit => '拖曳矩形移動，拉動角落調整大小',
                  },
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: '刪除選取矩形',
                onPressed: _selectedIndex == null
                    ? null
                    : _deleteSelected,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionList() {
    return SizedBox(
      height: 200,
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text('框選區域 (${_rects.length})'),
            subtitle: const Text('點選清單項目，再切換至調整框模式'),
          ),
          Expanded(
            child: _rects.isEmpty
                ? const Center(child: Text('尚未建立框選區域'))
                : ListView.builder(
              itemCount: _rects.length,
              itemBuilder: (context, index) {
                final rect = _rects[index];
                final selected = index == _selectedIndex;

                return ListTile(
                  dense: true,
                  selected: selected,
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${index + 1}'),
                  ),
                  title: Text('區域 ${index + 1}'),
                  subtitle: Text(
                    '${_formatRect(rect)}\n'
                        '${_formatPixels(rect)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  isThreeLine: true,
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _SelectionPainter extends CustomPainter {
  const _SelectionPainter({
    required this.rects,
    required this.draftRect,
    required this.selectedIndex,
    required this.canvasSize,
  });

  final List<Rect> rects;
  final Rect? draftRect;
  final int? selectedIndex;
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

    for (int i = 0; i < rects.length; i++) {
      final rect = toCanvasRect(rects[i]);

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(
        rect,
        i == selectedIndex ? selectedPaint : borderPaint,
      );

      if (i == selectedIndex) {
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
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) {
    // 清單採用原地修改，因此直接重繪，避免參考相同造成漏更新。
    return true;
  }
}

