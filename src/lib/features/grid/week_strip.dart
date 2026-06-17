import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/time_block_store.dart';
import '../../core/models/date_key.dart';
import 'record_dot.dart';

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
class WeekStrip extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateKey.today();
    final sunday = weekStartDate(selectedDate);
    final saturday = sunday.add(const Duration(days: 6));
    final colorScheme = Theme.of(context).colorScheme;

    // Dates with records in the displayed week; empty while loading/on error.
    final recordDates = ref.watch(timeBlocksRangeProvider((sunday, saturday)))
        .maybeWhen(
          data: recordDatesOf,
          orElse: () => const <DateKey>{},
        );

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
              hasRecord: recordDates.contains(cellDate),
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
    required this.hasRecord,
    required this.colorScheme,
    required this.onTap,
  });

  final DateKey date;
  final String label;
  final WeekCellState state;
  final bool hasRecord;
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

    // Dot slot: today → primary dot; other record day → grey dot; else empty.
    // Today's dot wins so the two never overlap in the shared slot.
    final Widget dot;
    if (isToday) {
      dot = Padding(
        padding: const EdgeInsets.only(top: 2),
        child: RecordDot(color: colorScheme.primary),
      );
    } else if (hasRecord) {
      dot = const Padding(
        padding: EdgeInsets.only(top: 2),
        child: RecordDot(),
      );
    } else {
      dot = const SizedBox(height: 6);
    }

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
