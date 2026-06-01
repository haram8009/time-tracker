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
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom:
                BorderSide(color: Theme.of(context).dividerColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}
