import 'package:flutter/material.dart';

import '../models/seating_map_types.dart';

class SeatingMapToolbar extends StatelessWidget {
  const SeatingMapToolbar({
    required this.mode,
    required this.hasSelection,
    required this.onModeChanged,
    required this.onEditName,
    required this.onDelete,
    super.key,
  });

  final MapMode mode;
  final bool hasSelection;
  final ValueChanged<MapMode> onModeChanged;
  final VoidCallback onEditName;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
            selected: {mode},
            onSelectionChanged: (selection) {
              onModeChanged(selection.first);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  switch (mode) {
                    MapMode.browse => '拖曳與縮放底圖',
                    MapMode.draw => '在圖片上拖曳建立矩形',
                    MapMode.edit => '拖曳矩形移動，拉動角落調整大小',
                  },
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: '設定或修改姓名',
                onPressed: hasSelection ? onEditName : null,
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                tooltip: '刪除選取矩形',
                onPressed: hasSelection ? onDelete : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
