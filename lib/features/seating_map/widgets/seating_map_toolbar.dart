import 'package:flutter/material.dart';

import '../models/seating_map_types.dart';

class SeatingMapToolbar extends StatelessWidget {
  const SeatingMapToolbar({
    required this.isEditing,
    required this.mode,
    required this.hasSelection,
    required this.onToggleEditing,
    required this.onModeChanged,
    required this.onEditName,
    required this.onDelete,
    required this.rotationDegrees,
    required this.onRotate,
    required this.onImportImage,
    required this.onExportData,
    required this.onImportData,
    super.key,
  });

  final bool isEditing;
  final MapMode mode;
  final bool hasSelection;
  final VoidCallback onToggleEditing;
  final ValueChanged<MapMode> onModeChanged;
  final VoidCallback onEditName;
  final VoidCallback onDelete;
  final int rotationDegrees;
  final VoidCallback onRotate;
  final VoidCallback onImportImage;
  final VoidCallback onExportData;
  final VoidCallback onImportData;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onToggleEditing,
                icon: Icon(isEditing ? Icons.check : Icons.edit),
                label: Text(isEditing ? '完成編輯' : '編輯'),
              ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: 8),
            SegmentedButton<MapMode>(
              segments: const [
                ButtonSegment(
                  value: MapMode.draw,
                  icon: Icon(Icons.crop_free),
                  label: Text('新增框'),
                ),
                ButtonSegment(
                  value: MapMode.edit,
                  icon: Icon(Icons.open_with),
                  label: Text('移動／調整'),
                ),
              ],
              selected: {mode == MapMode.draw ? MapMode.draw : MapMode.edit},
              onSelectionChanged: (selection) => onModeChanged(selection.first),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    mode == MapMode.draw
                        ? '在圖片上拖曳建立矩形'
                        : '拖曳矩形移動，拉動角落調整大小',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: '設定或修改姓名',
                  onPressed: hasSelection ? onEditName : null,
                  icon: const Icon(Icons.edit_note),
                ),
                IconButton(
                  tooltip: '順時針旋轉 90°（目前：$rotationDegrees°）',
                  onPressed: onRotate,
                  icon: const Icon(Icons.rotate_right),
                ),
                Text('$rotationDegrees°'),
                IconButton(
                  tooltip: '刪除選取矩形',
                  onPressed: hasSelection ? onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onImportImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: const Text('匯入圖片'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onExportData,
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: const Text('匯出資料'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onImportData,
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text('匯入資料'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
