import 'package:flutter/material.dart';

/// Returns the Sunday that begins the week containing [date].
DateTime weekStartDate(DateTime date) {
  // weekday: Mon=1 ... Sun=7; we want Sunday=0 offset
  final daysSinceSunday = date.weekday % 7; // Mon=1->1, Sun=7->0
  return DateTime(date.year, date.month, date.day - daysSinceSunday);
}

/// Visual state of a day cell in the week strip.
enum WeekCellState {
  selected,
  today,
  future,
  normal,
}

/// Pure fn — determines cell state given cell date, selected date, today.
WeekCellState weekCellState(
  DateTime cellDate,
  DateTime selectedDate,
  DateTime today,
) {
  final cell = DateTime(cellDate.year, cellDate.month, cellDate.day);
  final sel = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final tod = DateTime(today.year, today.month, today.day);

  if (cell.isAfter(tod)) return WeekCellState.future;
  if (cell == sel) return WeekCellState.selected;
  if (cell == tod) return WeekCellState.today;
  return WeekCellState.normal;
}

/// Horizontal 7-day strip showing the week that contains [selectedDate].
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final void Function(DateTime) onDateSelected;

  static const double height = 56.0;
  static const List<String> _labels = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final sunday = weekStartDate(selectedDate);
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: height,
      child: Row(
        children: List.generate(7, (i) {
          final cellDate = sunday.add(Duration(days: i));
          final state = weekCellState(cellDate, selectedDate, today);
          return Expanded(
            child: _DayCell(
              date: cellDate,
              label: _labels[i],
              state: state,
              colorScheme: colorScheme,
              onTap: state == WeekCellState.future
                  ? null
                  : () => onDateSelected(cellDate),
            ),
          );
        }),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.label,
    required this.state,
    required this.colorScheme,
    required this.onTap,
  });

  final DateTime date;
  final String label;
  final WeekCellState state;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = state == WeekCellState.selected;
    final isToday = state == WeekCellState.today;
    final isFuture = state == WeekCellState.future;

    final numberText = Text(
      '${date.day}',
      style: TextStyle(
        fontSize: 15,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
      ),
    );

    final circle = isSelected
        ? Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: numberText,
          )
        : SizedBox(
            width: 32,
            height: 32,
            child: Center(child: numberText),
          );

    final dot = isToday
        ? Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          )
        : const SizedBox(height: 6); // keep height consistent

    Widget cell = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 2),
        circle,
        dot,
      ],
    );

    if (isFuture) {
      cell = Opacity(opacity: 0.3, child: cell);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: cell,
    );
  }
}
