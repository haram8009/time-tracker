import 'package:flutter/material.dart';
import '../../../core/models/category.dart';
import '../../../core/models/time_block.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/models/time_block_style.dart';
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
        final cellSlotWidth = availableWidth / 6;

        final segments = <Widget>[];
        for (final item in positioned) {
          final block = item.block;
          final color = colorMap[block.categoryId] ?? Colors.grey;
          final label = nameMap[block.categoryId] ?? '';

          final startCellIdx = block.startMinute ~/ 10;
          final endCellIdx = (block.endMinute - 1) ~/ 10;
          final startRow = startCellIdx ~/ 6;
          final endRow = endCellIdx ~/ 6;

          for (int row = startRow; row <= endRow; row++) {
            final rowStartCell = row * 6;
            final firstCol = (startCellIdx - rowStartCell).clamp(0, 5);
            final lastCol = (endCellIdx - rowStartCell).clamp(0, 5);
            final numCols = lastCol - firstCol + 1;

            final top = row.toDouble() * cellHeight;
            final segLeft = timeLabelWidth + firstCol * cellSlotWidth;
            final segWidth = (numCols * cellSlotWidth - 2.0).clamp(0.0, double.infinity);
            final isFirst = row == startRow;

            const double blockInset = 2.0;
            final segHeight = cellHeight - blockInset * 2;
            segments.add(Positioned(
              top: top + blockInset,
              left: segLeft,
              width: segWidth,
              height: segHeight,
              child: BlockRenderer(
                style: style,
                color: color,
                label: isFirst ? label : '',
                height: segHeight,
              ),
            ));
          }
        }

        return IgnorePointer(
          child: SizedBox(
            width: constraints.maxWidth,
            height: 24 * cellHeight,
            child: Stack(children: segments),
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
