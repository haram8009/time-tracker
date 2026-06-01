import 'package:flutter/material.dart';

class DragSelectionOverlay extends StatelessWidget {
  final Set<int> selectedIndices;
  final double cellHeight;
  final double timeLabelWidth;

  const DragSelectionOverlay({
    super.key,
    required this.selectedIndices,
    required this.cellHeight,
    required this.timeLabelWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedIndices.isEmpty) return const SizedBox.shrink();

    final color =
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.15);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - timeLabelWidth;
        final cellWidth = availableWidth / 6;

        return IgnorePointer(
          child: SizedBox(
            width: constraints.maxWidth,
            height: 24 * cellHeight,
            child: Stack(
              children: selectedIndices.map((idx) {
                final col = idx % 6;
                final row = idx ~/ 6;
                return Positioned(
                  left: timeLabelWidth + col * cellWidth,
                  top: row * cellHeight,
                  width: cellWidth,
                  height: cellHeight,
                  child: ColoredBox(color: color),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
