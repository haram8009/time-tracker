import 'package:flutter/material.dart';
import '../../../core/models/cell_state.dart';

class GridCell extends StatelessWidget {
  final int index;
  final CellState state;
  final VoidCallback? onTap;

  const GridCell({
    super.key,
    required this.index,
    required this.state,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _CellBody(state: state),
    );
  }
}

class _CellBody extends StatelessWidget {
  final CellState state;

  const _CellBody({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1.5),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (state.isSelected)
            Container(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            ),
          if (state.thumbnails.isNotEmpty)
            Positioned(
              right: 2,
              top: 4,
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: state.thumbnails.map((bytes) {
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
        ],
      ),
    );
  }
}
