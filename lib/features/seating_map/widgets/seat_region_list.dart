import 'package:flutter/material.dart';

import '../models/seat_region.dart';

class SeatRegionList extends StatefulWidget {
  const SeatRegionList({
    required this.regions,
    required this.selectedIndex,
    required this.formatRect,
    required this.formatPixels,
    required this.onSelected,
    super.key,
  });

  final List<SeatRegion> regions;
  final int? selectedIndex;
  final String Function(Rect rect) formatRect;
  final String Function(Rect rect) formatPixels;
  final ValueChanged<int> onSelected;

  @override
  State<SeatRegionList> createState() => _SeatRegionListState();
}

class _SeatRegionListState extends State<SeatRegionList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final regions = widget.regions;
    final selectedIndex = widget.selectedIndex;

    return SafeArea(
      top: false,
      bottom: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        // 限制底部列表高度，並由 SafeArea 預留系統導覽列空間。
        height: _expanded ? 148 : 44,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '框選區域 (${regions.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: _expanded ? '收起座標清單' : '展開座標清單',
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(_expanded ? Icons.expand_more : Icons.expand_less),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            if (_expanded)
              Expanded(
                child: regions.isEmpty
                    ? const Center(child: Text('尚未建立框選區域'))
                    : ListView.builder(
                        itemCount: regions.length,
                        itemBuilder: (context, index) {
                          final region = regions[index];
                          final selected = index == selectedIndex;

                          return ListTile(
                            dense: true,
                            selected: selected,
                            leading: CircleAvatar(
                              radius: 14,
                              child: Text('${index + 1}'),
                            ),
                            title: Text(
                              region.name.isEmpty
                                  ? '區域 ${index + 1}（未命名）'
                                  : region.name,
                            ),
                            subtitle: Text(
                              '${widget.formatRect(region.rect)}\n'
                              '${widget.formatPixels(region.rect)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            isThreeLine: true,
                            onTap: () => widget.onSelected(index),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
