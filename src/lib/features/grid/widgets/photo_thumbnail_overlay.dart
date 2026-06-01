import 'package:flutter/material.dart';
import '../../../core/models/cell_state.dart';

class PhotoThumbnailOverlay extends StatelessWidget {
  final List<CellState> cells;
  final double cellHeight;
  final double timeLabelWidth;

  const PhotoThumbnailOverlay({
    super.key,
    required this.cells,
    required this.cellHeight,
    required this.timeLabelWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (!cells.any((c) => c.thumbnails.isNotEmpty)) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - timeLabelWidth;
        final cellWidth = availableWidth / 6;

        final items = <Widget>[];
        for (var idx = 0; idx < cells.length; idx++) {
          final cell = cells[idx];
          if (cell.thumbnails.isEmpty) continue;

          final col = idx % 6;
          final row = idx ~/ 6;

          items.add(Positioned(
            left: timeLabelWidth + col * cellWidth,
            top: row * cellHeight,
            width: cellWidth,
            height: cellHeight,
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 2, top: 4, bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: cell.thumbnails.map((bytes) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Image.memory(
                          bytes,
                          width: 24,
                          height: 24,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          ));
        }

        return IgnorePointer(
          child: SizedBox(
            width: constraints.maxWidth,
            height: 24 * cellHeight,
            child: Stack(children: items),
          ),
        );
      },
    );
  }
}
