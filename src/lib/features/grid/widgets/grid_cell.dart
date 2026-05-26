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

  bool get _isHourMark => index % 6 == 0;

  String get _timeLabel {
    if (_isHourMark) {
      final hour = index ~/ 6;
      return '${hour.toString().padLeft(2, '0')}:00';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  _timeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: _CellBody(
                state: state,
                isHourMark: _isHourMark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CellBody extends StatelessWidget {
  final CellState state;
  final bool isHourMark;

  const _CellBody({
    required this.state,
    required this.isHourMark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isHourMark ? Colors.grey.shade400 : Colors.grey.shade300,
            width: isHourMark ? 1.0 : 0.5,
          ),
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
