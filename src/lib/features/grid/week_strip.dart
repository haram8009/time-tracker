import 'package:flutter/material.dart';
import '../../core/models/date_key.dart';

/// Returns the Sunday that begins the week containing [date].
DateKey weekStartDate(DateKey date) {
  final daysSinceSunday = date.toDateTime().weekday % 7;
  return date.add(Duration(days: -daysSinceSunday));
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
  DateKey cellDate,
  DateKey selectedDate,
  DateKey today,
) {
  if (cellDate.isAfter(today)) return WeekCellState.future;
  if (cellDate == selectedDate) return WeekCellState.selected;
  if (cellDate == today) return WeekCellState.today;
  return WeekCellState.normal;
}

/// Horizontal 7-day strip showing the week that contains [selectedDate].
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateKey selectedDate;
  final void Function(DateKey) onDateSelected;

  static const double height = 56.0;
  static const List<String> _labels = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final today = DateKey.today();
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

  final DateKey date;
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
        : const SizedBox(height: 6);

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
