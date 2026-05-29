import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

/// Opens a full-height bottom-sheet calendar. Calls [onDateSelected] and
/// closes when the user taps a day. Year-view is added in #59.
Future<void> showCalendarModal({
  required BuildContext context,
  required DateTime selectedDate,
  required void Function(DateTime) onDateSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _CalendarModalContent(
      selectedDate: selectedDate,
      onDateSelected: onDateSelected,
    ),
  );
}

class _CalendarModalContent extends StatefulWidget {
  const _CalendarModalContent({
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final void Function(DateTime) onDateSelected;

  @override
  State<_CalendarModalContent> createState() => _CalendarModalContentState();
}

class _CalendarModalContentState extends State<_CalendarModalContent> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  static final DateTime _firstDay = DateTime(2020, 1, 1);

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    final d = widget.selectedDate;
    _selectedDay = DateTime(d.year, d.month, d.day);
    _focusedDay = _selectedDay;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = _today;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: TableCalendar<void>(
          firstDay: _firstDay,
          lastDay: today,
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: ''},
          startingDayOfWeek: StartingDayOfWeek.sunday,
          onDaySelected: (selectedDay, focusedDay) {
            if (selectedDay.isAfter(today)) return;
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            final d = DateTime(
                selectedDay.year, selectedDay.month, selectedDay.day);
            widget.onDateSelected(d);
            Navigator.of(context).pop();
          },
          onPageChanged: (focusedDay) {
            setState(() => _focusedDay = focusedDay);
          },
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            outsideDaysVisible: false,
            disabledTextStyle: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          enabledDayPredicate: (day) => !day.isAfter(today),
        ),
      ),
    );
  }
}
