import 'package:flutter/material.dart';

import '../models/seat_region.dart';

class SeatRegionList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text('框選區域 (${regions.length})'),
            subtitle: const Text('點選清單項目，再切換至調整框模式'),
          ),
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
                          '${formatRect(region.rect)}\n'
                          '${formatPixels(region.rect)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        isThreeLine: true,
                        onTap: () => onSelected(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
