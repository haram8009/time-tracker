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
          bottom: BorderSide(color: Colors.grey.shade400, width: 1.0),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (state.categoryColor != null)
            Container(
              color: Color.fromARGB(
                (state.categoryColor!.a * 255).round(),
                (state.categoryColor!.r * 255).round(),
                (state.categoryColor!.g * 255).round(),
                (state.categoryColor!.b * 255).round(),
              ),
            ),
          if (state.isSelected)
            Container(
              color: Colors.blue.withValues(alpha: 0.3),
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
