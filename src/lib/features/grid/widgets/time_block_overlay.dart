import 'package:flutter/material.dart';
import '../../../core/models/category.dart';
import '../../../core/models/time_block.dart';
import '../../../core/utils/time_utils.dart';
import '../models/time_block_style.dart';
import 'block_renderer.dart';

class TimeBlockOverlay extends StatelessWidget {
  final List<TimeBlock> blocks;
  final List<Category> categories;
  final TimeBlockStyle style;
  final double cellHeight;
  final double timeLabelWidth;

  const TimeBlockOverlay({
    super.key,
    required this.blocks,
    required this.categories,
    required this.style,
    required this.cellHeight,
    required this.timeLabelWidth,
  });

  @override
  Widget build(BuildContext context) {
    final colorMap = <int, Color>{
      for (final c in categories)
        if (c.id != null) c.id!: hexToColor(c.colorHex),
    };
    final nameMap = <int, String>{
      for (final c in categories)
        if (c.id != null) c.id!: c.name,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - timeLabelWidth;
        final positioned = _layoutBlocks(blocks, availableWidth);

        return IgnorePointer(
          child: SizedBox(
            width: constraints.maxWidth,
            height: 24 * cellHeight,
            child: Stack(
              children: positioned.map((item) {
                final block = item.block;
                final color = colorMap[block.categoryId] ?? Colors.grey;
                final label = nameMap[block.categoryId] ?? '';
                final top = (block.startMinute / 60.0) * cellHeight;
                final height =
                    ((block.endMinute - block.startMinute) / 60.0) * cellHeight;
                final left = timeLabelWidth + item.xOffset;
                final width = item.columnWidth - 2.0;

                return Positioned(
                  top: top,
                  left: left,
                  width: width.clamp(0.0, double.infinity),
                  height: height.clamp(0.0, double.infinity),
                  child: BlockRenderer(
                    style: style,
                    color: color,
                    label: label,
                    height: height,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  List<_PositionedBlock> _layoutBlocks(
    List<TimeBlock> blocks,
    double availableWidth,
  ) {
    final sorted = [...blocks]
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    final result = <_PositionedBlock>[];

    for (final block in sorted) {
      final concurrent = sorted
          .where(
            (b) =>
                b.startMinute < block.endMinute &&
                b.endMinute > block.startMinute,
          )
          .toList();
      final n = concurrent.length;
      final myIndex = concurrent.indexOf(block);
      final colWidth = availableWidth / n;

      result.add(
        _PositionedBlock(
          block: block,
          xOffset: myIndex.toDouble() * colWidth,
          columnWidth: colWidth,
        ),
      );
    }
    return result;
  }
}

class _PositionedBlock {
  final TimeBlock block;
  final double xOffset;
  final double columnWidth;

  const _PositionedBlock({
    required this.block,
    required this.xOffset,
    required this.columnWidth,
  });
}
