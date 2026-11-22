import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'data/seat_region_repository.dart';
import 'data/seating_map_settings_repository.dart';
import 'models/seat_region.dart';
import 'models/seating_map_types.dart';
import 'widgets/name_editor_dialog.dart';
import 'widgets/seat_region_list.dart';
import 'widgets/seating_map_canvas.dart';
import 'widgets/seating_map_toolbar.dart';

class SeatingMapPage extends StatefulWidget {
  const SeatingMapPage({super.key});

  @override
  State<SeatingMapPage> createState() => _SeatingMapPageState();
}

class _SeatingMapPageState extends State<SeatingMapPage> {
  // 底圖採用固定的邏輯座標系統。
  static const double defaultMapWidth = 1086;
  static const double defaultMapHeight = 1448;
  double mapWidth = defaultMapWidth;
  double mapHeight = defaultMapHeight;
  String? _imagePath;

  // 四角控制點的點選範圍，以底圖座標計算。
  static const double handleHitRadius = 30;

  // 避免矩形縮小到無法選取。
  static const double minRectSize = 0.005;

  final TransformationController _transformationController =
      TransformationController();
  final SeatRegionRepository _repository = SeatRegionRepository();
  final SeatingMapSettingsRepository _settingsRepository =
      SeatingMapSettingsRepository();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _highlightedRegionId;
  Size? _mapViewportSize;
  int _rotationQuarterTurns = 0;

  MapMode _mode = MapMode.browse;
  bool _isEditing = false;
  final List<SeatRegion> _regions = [];

  int? _selectedIndex;
  Offset? _gestureStart;
  Rect? _draftRect;
  Rect? _initialRect;
  ResizeHandle? _activeHandle;
  bool _draggingMap = false;
  Offset? _lastMapPointer;
  final Set<int> _activePointerIds = <int>{};
  bool _multiTouchInProgress = false;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    try {
      final results = await Future.wait<Object?>([
        _repository.getAll(),
        _settingsRepository.getRotationQuarterTurns(),
        _settingsRepository.getImagePath(),
        _settingsRepository.getImageSize(defaultWidth: defaultMapWidth, defaultHeight: defaultMapHeight),
      ]);
      final regions = results[0] as List<SeatRegion>;
      final rotationQuarterTurns = results[1] as int;
      final imagePath = results[2] as String?;
      final imageSize = results[3] as Size;
      if (!mounted) return;

      setState(() {
        _regions
          ..clear()
          ..addAll(regions);
        _rotationQuarterTurns = rotationQuarterTurns;
        _imagePath = imagePath;
        mapWidth = imageSize.width;
        mapHeight = imageSize.height;
        _isLoading = false;
        _loadError = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitMapToViewport();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  void _showError(String action, Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action失敗：$error')),
    );
  }

  double _clamp(double value, double min, double max) {
    return value.clamp(min, max).toDouble();
  }

  // 將圖片上的邏輯座標轉成 0～1 的相對座標。
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

  ResizeHandle? _findHandle(Rect rect, Offset point) {
    final corners = <ResizeHandle, Offset>{
      ResizeHandle.topLeft: Offset(rect.left, rect.top),
      ResizeHandle.topRight: Offset(rect.right, rect.top),
      ResizeHandle.bottomLeft: Offset(rect.left, rect.bottom),
      ResizeHandle.bottomRight: Offset(rect.right, rect.bottom),
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

  int? _findRect(Offset point) {
    // 從最上層矩形開始測試命中。
    for (var index = _regions.length - 1; index >= 0; index--) {
      if (_regions[index].rect.contains(point)) {
        return index;
      }
    }
    return null;
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointerIds.add(event.pointer);
    if (_activePointerIds.length > 1) {
      _multiTouchInProgress = true;
      _gestureStart = null;
      _draftRect = null;
      _initialRect = null;
      _activeHandle = null;
      _draggingMap = false;
      _lastMapPointer = null;
      return;
    }
    if (_isSaving) return;

    final point = _normalizePoint(event.localPosition);

    if (_mode == MapMode.edit) {
      // 已選取框的控制點優先命中，確保可從框角開始調整大小。
      if (_selectedIndex != null) {
        final selectedRect = _regions[_selectedIndex!].rect;
        final handle = _findHandle(selectedRect, point);
        if (handle != null) {
          setState(() {
            _gestureStart = point;
            _activeHandle = handle;
            _initialRect = selectedRect;
          });
          return;
        }
      }

      final index = _findRect(point);
      if (index == null) {
        // 沒有碰到任何座位框時，拖曳整張地圖。
        _draggingMap = true;
        _lastMapPointer = event.position;
        return;
      }

      // 碰到座位框本體時，選取並移動該框。
      setState(() {
        _gestureStart = point;
        _activeHandle = null;
        _selectedIndex = index;
        _initialRect = _regions[index].rect;
      });
      return;
    }

    if (_mode == MapMode.draw) {
      setState(() {
        _gestureStart = point;
        _activeHandle = null;
        _initialRect = null;
        _draftRect = Rect.fromPoints(point, point);
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_multiTouchInProgress || _activePointerIds.length > 1) return;

    if (_draggingMap) {
      final previous = _lastMapPointer;
      if (previous == null) return;
      final delta = event.position - previous;
      _lastMapPointer = event.position;

      // 直接更新矩陣的畫面位移，避免平移量受到目前縮放倍率影響。
      final nextTransform = Matrix4.copy(_transformationController.value)
        ..setEntry(
          0,
          3,
          _transformationController.value.entry(0, 3) + delta.dx,
        )
        ..setEntry(
          1,
          3,
          _transformationController.value.entry(1, 3) + delta.dy,
        );
      _transformationController.value = _clampMapTransform(nextTransform);
      return;
    }

    if (_gestureStart == null) return;

    final point = _normalizePoint(event.localPosition);

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
        final left = _clamp(initial.left + dx, 0, 1 - initial.width);
        final top = _clamp(initial.top + dy, 0, 1 - initial.height);

        _regions[_selectedIndex!] = _regions[_selectedIndex!].copyWith(
          rect: Rect.fromLTWH(left, top, initial.width, initial.height),
        );
      } else {
        // 調整指定角落，其他角落保持固定。
        var left = initial.left;
        var top = initial.top;
        var right = initial.right;
        var bottom = initial.bottom;

        switch (_activeHandle!) {
          case ResizeHandle.topLeft:
            left = _clamp(initial.left + dx, 0, right - minRectSize);
            top = _clamp(initial.top + dy, 0, bottom - minRectSize);
          case ResizeHandle.topRight:
            right = _clamp(initial.right + dx, left + minRectSize, 1);
            top = _clamp(initial.top + dy, 0, bottom - minRectSize);
          case ResizeHandle.bottomLeft:
            left = _clamp(initial.left + dx, 0, right - minRectSize);
            bottom = _clamp(initial.bottom + dy, top + minRectSize, 1);
          case ResizeHandle.bottomRight:
            right = _clamp(initial.right + dx, left + minRectSize, 1);
            bottom = _clamp(initial.bottom + dy, top + minRectSize, 1);
        }

        _regions[_selectedIndex!] = _regions[_selectedIndex!].copyWith(
          rect: Rect.fromLTRB(left, top, right, bottom),
        );
      }
    });
  }

  void _onPointerUp(PointerEvent event) {
    _activePointerIds.remove(event.pointer);
    if (_activePointerIds.isNotEmpty) {
      _multiTouchInProgress = true;
      return;
    }
    if (_multiTouchInProgress) {
      _multiTouchInProgress = false;
      _gestureStart = null;
      _draftRect = null;
      _initialRect = null;
      _activeHandle = null;
      _draggingMap = false;
      _lastMapPointer = null;
      return;
    }
    _finishPointerGesture();
  }

  Matrix4 _clampMapTransform(Matrix4 transform) {
    final viewport = _mapViewportSize;
    if (viewport == null) return transform;

    final scaleX = transform.entry(0, 0).abs();
    final scaleY = transform.entry(1, 1).abs();
    final contentWidth = (_rotationQuarterTurns.isOdd ? mapHeight : mapWidth) * scaleX;
    final contentHeight = (_rotationQuarterTurns.isOdd ? mapWidth : mapHeight) * scaleY;
    final minX = math.min(0.0, viewport.width - contentWidth);
    final minY = math.min(0.0, viewport.height - contentHeight);
    final maxX = math.max(0.0, viewport.width - contentWidth);
    final maxY = math.max(0.0, viewport.height - contentHeight);

    return Matrix4.copy(transform)
      ..setEntry(0, 3, _clamp(transform.entry(0, 3), minX, maxX))
      ..setEntry(1, 3, _clamp(transform.entry(1, 3), minY, maxY));
  }

  Future<void> _finishPointerGesture() async {
    if (_draggingMap) {
      _draggingMap = false;
      _lastMapPointer = null;
      return;
    }

    final wasDrawing = _mode == MapMode.draw;
    final completedDraft = _draftRect;
    final selectedIndex = _selectedIndex;
    final originalRect = _initialRect;

    setState(() {
      _gestureStart = null;
      _draftRect = null;
      _initialRect = null;
      _activeHandle = null;
    });

    if (wasDrawing) {
      final rect = completedDraft;
      if (rect == null ||
          rect.width < minRectSize ||
          rect.height < minRectSize) {
        return;
      }

      final newRegion = SeatRegion(
        name: '',
        rect: rect,
        sortOrder: _regions.length,
      );

      setState(() => _isSaving = true);
      try {
        final savedRegion = await _repository.insert(newRegion);
        if (!mounted) return;
        setState(() {
          _regions.add(savedRegion);
          _selectedIndex = _regions.length - 1;
          _isSaving = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        _showError('新增座位框', error);
      }
      return;
    }

    if (_mode == MapMode.edit &&
        selectedIndex != null &&
        originalRect != null &&
        selectedIndex < _regions.length) {
      final updatedRegion = _regions[selectedIndex];
      if (updatedRegion.rect == originalRect) return;

      setState(() => _isSaving = true);
      try {
        await _repository.update(updatedRegion);
        if (!mounted) return;
        setState(() => _isSaving = false);
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _regions[selectedIndex] =
              _regions[selectedIndex].copyWith(rect: originalRect);
          _isSaving = false;
        });
        _showError('儲存座位框位置', error);
      }
    }
  }

  void _fitMapToViewport() {
    final viewportSize = _mapViewportSize;
    if (viewportSize == null || viewportSize.isEmpty) return;

    final displayedWidth = _rotationQuarterTurns.isOdd ? mapHeight : mapWidth;
    final displayedHeight = _rotationQuarterTurns.isOdd ? mapWidth : mapHeight;
    final scale = math
        .max(
          viewportSize.width / displayedWidth,
          viewportSize.height / displayedHeight,
        )
        .clamp(0.5, 5.0)
        .toDouble();
    final translationX = (viewportSize.width - displayedWidth * scale) / 2;
    final translationY = (viewportSize.height - displayedHeight * scale) / 2;

    _transformationController.value = Matrix4.identity()
      ..translate(translationX, translationY)
      ..scale(scale);
  }

  Future<void> _rotateMap() async {
    if (_isSaving) return;

    final previousRotation = _rotationQuarterTurns;
    final nextRotation = (previousRotation + 1) % 4;

    // 旋轉後先回到原始視角，避免舊的平移矩陣令底圖移出畫面。
    setState(() {
      _rotationQuarterTurns = nextRotation;
      _isSaving = true;
    });
    _fitMapToViewport();

    try {
      await _settingsRepository.saveRotationQuarterTurns(nextRotation);
      if (!mounted) return;
      setState(() => _isSaving = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _rotationQuarterTurns = previousRotation;
        _isSaving = false;
      });
      _fitMapToViewport();
      _showError('儲存地圖旋轉方向', error);
    }
  }

  Future<void> _importImage() async {
    if (!_isEditing || _isSaving) return;
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('匯入地圖圖片'),
        content: const Text('要如何處理目前的座位框？\n\n「保留」會保留原有框的相對比例位置，並套用到新圖片。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('保留座位資料')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('清空座位資料')),
        ],
      ),
    );
    if (choice == null) return;

    // file_picker 13.x 使用 FilePicker.pickFile()，單檔直接回傳 PlatformFile?
    // 不再使用 pickFiles() 的 allowMultiple / withData 參數。
    PlatformFile? file;
    try {
      file = await FilePicker.pickFile(type: FileType.image);
    } catch (error) {
      _showError('選取圖片', error);
      return;
    }
    if (file == null) return;

    late final Uint8List bytes;
    try {
      // v13 改為選取後明確讀取檔案內容，支援暫存路徑及雲端檔案。
      bytes = await file.readAsBytes();
    } catch (error) {
      _showError('讀取圖片', error);
      return;
    }

    ui.Codec? codec;
    ui.Image? decoded;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      decoded = (await codec.getNextFrame()).image;
      final width = decoded.width.toDouble();
      final height = decoded.height.toDouble();
      final directory = await getApplicationDocumentsDirectory();
      final extension = _imageExtension(file.name);
      final destination = File('${directory.path}/seating_map_background.$extension');
      await destination.writeAsBytes(bytes, flush: true);

      setState(() => _isSaving = true);
      if (choice) {
        await _repository.replaceAll(const []);
      }
      await _settingsRepository.saveImagePath(destination.path);
      await _settingsRepository.saveImageSize(Size(width, height));
      if (!mounted) return;
      setState(() {
        _imagePath = destination.path;
        mapWidth = width;
        mapHeight = height;
        if (choice) {
          _regions.clear();
          _selectedIndex = null;
          _highlightedRegionId = null;
        }
        _isSaving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToViewport());
    } catch (error) {
      if (mounted) setState(() => _isSaving = false);
      _showError('匯入圖片', error);
    } finally {
      decoded?.dispose();
      codec?.dispose();
    }
  }

  String _imageExtension(String name) {
    final extension = name.contains('.') ? name.split('.').last.toLowerCase() : 'png';
    return const {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'}.contains(extension)
        ? extension
        : 'png';
  }

  Future<void> _exportData() async {
    try {
      final regions = _regions.map((region) => {
        'name': region.name,
        'keywords': region.keywords,
        'left': region.rect.left,
        'top': region.rect.top,
        'right': region.rect.right,
        'bottom': region.rect.bottom,
        'sortOrder': region.sortOrder,
      }).toList();
      String? imageBase64;
      if (_imagePath != null) {
        final imageFile = File(_imagePath!);
        if (!await imageFile.exists()) {
          throw StateError('目前設定的地圖圖片檔案不存在，請重新匯入圖片後再備份。');
        }
        imageBase64 = base64Encode(await imageFile.readAsBytes());
      }
      final payload = <String, Object?>{
        'format': 'seating-map-backup',
        'version': 1,
        'rotationQuarterTurns': _rotationQuarterTurns,
        'imageWidth': mapWidth,
        'imageHeight': mapHeight,
        'imageExtension': _imagePath == null ? null : _imageExtension(_imagePath!),
        'imageBase64': imageBase64,
        'regions': regions,
      };
      final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)));
      // file_picker 13.x 的 saveFile 直接回傳 Uri?，並由 bytes 寫入檔案。
      // type / allowedExtensions 對 saveFile 沒有作用，故不傳入。
      final Uri? savedUri = await FilePicker.saveFile(
        dialogTitle: '匯出座位資料',
        fileName: 'seating_map_backup.json',
        bytes: bytes,
      );
      if (savedUri != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('座位資料已匯出')));
      }
    } catch (error) {
      _showError('匯出資料', error);
    }
  }

  Rect _clampImportedRect(Rect rect) => Rect.fromLTRB(
    rect.left.clamp(0.0, 1.0).toDouble(),
    rect.top.clamp(0.0, 1.0).toDouble(),
    rect.right.clamp(0.0, 1.0).toDouble(),
    rect.bottom.clamp(0.0, 1.0).toDouble(),
  );

  List<SeatRegion> _fitImportedRegions(List<SeatRegion> source) {
    if (source.isEmpty) return source;
    var bounds = source.map((region) => region.rect).reduce((a, b) => a.expandToInclude(b));
    // 若整組框超出圖片尺寸，等比例縮小整組框，保留彼此相對位置。
    final scale = math.min(1.0, math.min(1 / bounds.width, 1 / bounds.height));
    final scaled = source.map((region) {
      final rect = Rect.fromLTRB(
        bounds.center.dx + (region.rect.left - bounds.center.dx) * scale,
        bounds.center.dy + (region.rect.top - bounds.center.dy) * scale,
        bounds.center.dx + (region.rect.right - bounds.center.dx) * scale,
        bounds.center.dy + (region.rect.bottom - bounds.center.dy) * scale,
      );
      return region.copyWith(rect: rect);
    }).toList();
    bounds = scaled.map((region) => region.rect).reduce((a, b) => a.expandToInclude(b));
    final dx = bounds.left < 0 ? -bounds.left : (bounds.right > 1 ? 1 - bounds.right : 0.0);
    final dy = bounds.top < 0 ? -bounds.top : (bounds.bottom > 1 ? 1 - bounds.bottom : 0.0);
    return [
      for (var index = 0; index < scaled.length; index++)
        scaled[index].copyWith(
          rect: _clampImportedRect(scaled[index].rect.shift(Offset(dx, dy))),
          sortOrder: index,
        ),
    ];
  }

  Future<void> _importData() async {
    if (!_isEditing || _isSaving) return;
    PlatformFile? file;
    try {
      // file_picker 13.x 單檔選取使用 pickFile()，取消時回傳 null。
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
    } catch (error) {
      _showError('選取備份檔', error);
      return;
    }
    if (file == null) return;

    try {
      // v13 的 PlatformFile 使用 readAsBytes()，不再使用 withData / bytes 欄位。
      final bytes = await file.readAsBytes();
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (data['format'] != 'seating-map-backup' || data['version'] != 1) {
        throw const FormatException('不支援的座位資料格式或版本');
      }
      final rawRegions = data['regions'] as List<dynamic>;
      final imported = <SeatRegion>[];
      for (var index = 0; index < rawRegions.length; index++) {
        final item = rawRegions[index] as Map<String, dynamic>;
        final rect = Rect.fromLTRB(
          (item['left'] as num).toDouble(),
          (item['top'] as num).toDouble(),
          (item['right'] as num).toDouble(),
          (item['bottom'] as num).toDouble(),
        );
        if (!rect.left.isFinite || !rect.top.isFinite || !rect.right.isFinite || !rect.bottom.isFinite || rect.isEmpty) {
          throw FormatException('第 ${index + 1} 個座位框座標無效');
        }
        imported.add(SeatRegion(
          name: item['name'] as String? ?? '',
          keywords: (item['keywords'] as List<dynamic>? ?? const []).map((value) => value.toString()).toList(),
          rect: rect,
          sortOrder: index,
        ));
      }
      final fittedRegions = _fitImportedRegions(imported);
      final rotation = ((data['rotationQuarterTurns'] as num?)?.toInt() ?? 0) % 4;
      final imageWidth = (data['imageWidth'] as num?)?.toDouble() ?? defaultMapWidth;
      final imageHeight = (data['imageHeight'] as num?)?.toDouble() ?? defaultMapHeight;
      if (!imageWidth.isFinite || !imageHeight.isFinite || imageWidth <= 0 || imageHeight <= 0) {
        throw const FormatException('備份檔中的圖片尺寸無效');
      }
      String? importedImagePath;
      Uint8List? importedImageBytes;
      String? importedImageExtension;
      final imageBase64 = data['imageBase64'] as String?;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        importedImageBytes = base64Decode(imageBase64);
        importedImageExtension = _imageExtension(
          'backup.${data['imageExtension'] ?? 'png'}',
        );
      }

      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('匯入座位資料'),
          content: Text('這會取代目前的 ${_regions.length} 個座位框，並載入備份中的 ${fittedRegions.length} 個座位框及地圖設定。是否繼續？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('取代並匯入')),
          ],
        ),
      );
      if (shouldReplace != true || !mounted) return;
      if (importedImageBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imageFile = File(
          '${directory.path}/seating_map_background.$importedImageExtension',
        );
        await imageFile.writeAsBytes(importedImageBytes, flush: true);
        importedImagePath = imageFile.path;
      }
      setState(() => _isSaving = true);
      await _repository.replaceAll(fittedRegions);
      final savedRegions = await _repository.getAll();
      await _settingsRepository.saveRotationQuarterTurns(rotation);
      await _settingsRepository.saveImageSize(Size(imageWidth, imageHeight));
      await _settingsRepository.saveImagePath(importedImagePath);
      if (!mounted) return;
      setState(() {
        _regions
          ..clear()
          ..addAll(savedRegions);
        _rotationQuarterTurns = rotation;
        mapWidth = imageWidth;
        mapHeight = imageHeight;
        _imagePath = importedImagePath;
        _selectedIndex = null;
        _highlightedRegionId = null;
        _isSaving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToViewport());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已匯入 ${savedRegions.length} 個座位框；超出圖片範圍的框已整組移回圖片內')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _isSaving = false);
      _showError('匯入資料', error);
    }
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
      _mode = _isEditing ? MapMode.edit : MapMode.browse;
      if (!_isEditing) {
        _selectedIndex = null;
      }
      _gestureStart = null;
      _draftRect = null;
      _initialRect = null;
      _activeHandle = null;
      _draggingMap = false;
      _lastMapPointer = null;
      _activePointerIds.clear();
      _multiTouchInProgress = false;
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

  Future<void> _deleteSelected() async {
    final index = _selectedIndex;
    if (index == null || _isSaving) return;

    final region = _regions[index];
    setState(() => _isSaving = true);

    try {
      await _repository.delete(region);
      if (!mounted) return;
      setState(() {
        _regions.removeAt(index);
        for (var i = 0; i < _regions.length; i++) {
          _regions[i] = _regions[i].copyWith(sortOrder: i);
        }
        _selectedIndex = null;
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('刪除座位框', error);
    }
  }

  Future<void> _editSelectedName() async {
    final index = _selectedIndex;
    if (index == null || _isSaving) return;

    final originalRegion = _regions[index];
    final result = await showDialog<Map<String, Object>>(
      context: context,
      builder: (_) => NameEditorDialog(
        initialName: originalRegion.name,
        initialKeywords: originalRegion.keywords,
      ),
    );

    if (!mounted || result == null) return;
    final name = result['name'] as String;
    final keywords = result['keywords'] as List<String>;
    if (name == originalRegion.name &&
        keywords.join('\u0000') == originalRegion.keywords.join('\u0000')) {
      return;
    }

    // 以資料庫 id 尋找原本的座位框，不依賴對話框開啟前的索引。
    final currentIndex =
        _regions.indexWhere((region) => region.id == originalRegion.id);
    if (currentIndex == -1) return;

    final updatedRegion = _regions[currentIndex].copyWith(
      name: name,
      keywords: keywords,
    );
    setState(() => _isSaving = true);

    try {
      await _repository.update(updatedRegion);
      if (!mounted) return;
      setState(() {
        _regions[currentIndex] = updatedRegion;
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('儲存姓名', error);
    }
  }

  List<int> get _searchResultIndices {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return const [];

    return [
      for (var index = 0; index < _regions.length; index++)
        if ([_regions[index].name, ..._regions[index].keywords]
            .any((value) => value.toLowerCase().contains(query)))
          index,
    ];
  }


  void _focusRegion(int index) {
    if (index < 0 || index >= _regions.length) return;

    // 搜尋只標示顏色，不改變地圖縮放或位置。
    FocusScope.of(context).unfocus();
    setState(() {
      _highlightedRegionId = _regions[index].id;
      _isEditing = false;
      _mode = MapMode.browse;
      _selectedIndex = null;
    });
  }

  String _percent(double value) => '${(value * 100).toStringAsFixed(2)}%';

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

    return '像素座標：X=$left, Y=$top, W=$width, H=$height';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('座位表編輯器'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('載入座位資料失敗'),
                          const SizedBox(height: 8),
                          Text(_loadError!),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _loadError = null;
                              });
                              _loadRegions();
                            },
                            child: const Text('重試'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SafeArea(
                    top: false,
                    bottom: true,
                    child: Column(
                    children: [
                      if (!_isEditing)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                              // 搜尋條件改變時，先取消上一筆結果的高亮。
                              _highlightedRegionId = null;
                            });
                          },
                          keyboardType: TextInputType.text,
                          enableSuggestions: true,
                          autocorrect: true,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            labelText: '搜尋姓名、部門或座位關鍵字',
                            hintText: '可輸入單字，例如：王、資訊、A-01',
                            border: const OutlineInputBorder(),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: '清除搜尋',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _highlightedRegionId = null;
                                      });
                                    },
                                  ),
                          ),
                        ),
                      ),
                      if (!_isEditing && _searchQuery.trim().isNotEmpty)
                        SizedBox(
                          height: math.min(160.0, 48.0 * _searchResultIndices.length + 8),
                          child: _searchResultIndices.isEmpty
                              ? const Center(child: Text('找不到符合的區域'))
                              : ListView.builder(
                                  itemCount: _searchResultIndices.length,
                                  itemBuilder: (context, resultIndex) {
                                    final regionIndex = _searchResultIndices[resultIndex];
                                    final region = _regions[regionIndex];
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.location_on_outlined),
                                      title: Text(region.name.isEmpty
                                          ? '區域 ${regionIndex + 1}（未命名）'
                                          : region.name),
                                      subtitle: region.keywords.isEmpty
                                          ? null
                                          : Text(region.keywords.join('、')),
                                      onTap: () => _focusRegion(regionIndex),
                                    );
                                  },
                                ),
                        ),
                      SeatingMapToolbar(
                        isEditing: _isEditing,
                        mode: _mode,
                        hasSelection: _selectedIndex != null,
                        onToggleEditing: _toggleEditing,
                        onModeChanged: _changeMode,
                        onEditName: _editSelectedName,
                        onDelete: _deleteSelected,
                        rotationDegrees: _rotationQuarterTurns * 90,
                        onRotate: _rotateMap,
                        onImportImage: _importImage,
                        onExportData: _exportData,
                        onImportData: _importData,
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final viewportSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            _mapViewportSize = viewportSize;
                            return SeatingMapCanvas(
                              mapWidth: mapWidth,
                              mapHeight: mapHeight,
                              imagePath: _imagePath,
                              transformationController: _transformationController,
                              mode: _mode,
                              regions: _regions,
                              draftRect: _draftRect,
                              selectedIndex: _selectedIndex,
                              highlightedIndex: _regions.indexWhere(
                                (region) => region.id == _highlightedRegionId,
                              ),
                              rotationQuarterTurns: _rotationQuarterTurns,
                              onPointerDown: _onPointerDown,
                              onPointerMove: _onPointerMove,
                              onPointerUp: _onPointerUp,
                            );
                          },
                        ),
                      ),
                      if (_isEditing)
                        SeatRegionList(
                          regions: _regions,
                          selectedIndex: _selectedIndex,
                          formatRect: _formatRect,
                          formatPixels: _formatPixels,
                          onSelected: (index) {
                            setState(() => _selectedIndex = index);
                          },
                        ),
                      if (_isSaving) const LinearProgressIndicator(),
                  ],
                ),
              ),
    );
  }
}
