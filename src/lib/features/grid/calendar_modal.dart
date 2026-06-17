import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/db/time_block_store.dart';
import '../../core/models/date_key.dart';
import 'record_dot.dart';

/// Opens a calendar bottom-sheet. Calls [onDateSelected] and closes on day tap.
/// Header year-label tap → year view (12-month grid) → month tap → back to month view.
Future<void> showCalendarModal({
  required BuildContext context,
  required DateKey selectedDate,
  required void Function(DateKey) onDateSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _CalendarModalContent(
      selectedDate: selectedDate.toDateTime(),
      onDateSelected: (dt) => onDateSelected(DateKey.fromDateTime(dt)),
    ),
  );
}

/// Tappable AppBar-title button that opens [showCalendarModal].
/// Shared by the records (grid) and analytics screens for a consistent header.
class CalendarHeaderButton extends StatelessWidget {
  const CalendarHeaderButton({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final String label;
  final DateKey selectedDate;
  final void Function(DateKey) onDateSelected;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => showCalendarModal(
        context: context,
        selectedDate: selectedDate,
        onDateSelected: onDateSelected,
      ),
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// "오늘" reset button for AppBar actions. Shared header element.
class TodayResetButton extends StatelessWidget {
  const TodayResetButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: const Text('오늘', style: TextStyle(fontSize: 14)),
    );
  }
}

class _CalendarModalContent extends ConsumerStatefulWidget {
  const _CalendarModalContent({
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final void Function(DateTime) onDateSelected;

  @override
  ConsumerState<_CalendarModalContent> createState() =>
      _CalendarModalContentState();
}

class _CalendarModalContentState extends ConsumerState<_CalendarModalContent> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  bool _yearViewActive = false;
  late int _yearViewYear;

  static final DateTime _firstDay = DateTime(2020, 1, 1);

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Date-only comparison (tz-safe). table_calendar passes UTC-midnight days,
  /// so a raw `isAfter` would wrongly mark today as future in +UTC zones.
  bool _isAfterToday(DateTime day) {
    return DateTime(day.year, day.month, day.day).isAfter(_today);
  }

  @override
  void initState() {
    super.initState();
    final d = widget.selectedDate;
    _selectedDay = DateTime(d.year, d.month, d.day);
    _focusedDay = _selectedDay;
    _yearViewYear = _focusedDay.year;
  }

  void _enterYearView() {
    setState(() {
      _yearViewYear = _focusedDay.year;
      _yearViewActive = true;
    });
  }

  void _onMonthTapped(int month) {
    setState(() {
      _focusedDay = DateTime(_yearViewYear, month, 1);
      _yearViewActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: _yearViewActive ? _buildYearView(context) : _buildMonthView(context),
      ),
    );
  }

  Widget _buildMonthView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = _today;

    // Records in the focused month (1st–last); empty while loading/on error.
    final monthStart = DateKey(_focusedDay.year, _focusedDay.month, 1);
    final monthEnd =
        DateKey.fromDateTime(DateTime(_focusedDay.year, _focusedDay.month + 1, 0));
    final recordDates = ref
        .watch(timeBlocksRangeProvider((monthStart, monthEnd)))
        .maybeWhen(data: recordDatesOf, orElse: () => const <DateKey>{});

    return TableCalendar<DateKey>(
      firstDay: _firstDay,
      lastDay: today,
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
      eventLoader: (day) {
        final key = DateKey.fromDateTime(day);
        return recordDates.contains(key) ? [key] : const [];
      },
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: ''},
      startingDayOfWeek: StartingDayOfWeek.sunday,
      onDaySelected: (selectedDay, focusedDay) {
        if (_isAfterToday(selectedDay)) return;
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        final d = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
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
        titleCentered: false,
        titleTextStyle:
            Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600),
        // Custom left widget with tappable year label
        leftChevronVisible: true,
        rightChevronVisible: true,
        headerPadding: EdgeInsets.zero,
        titleTextFormatter: (date, locale) => '${date.year}년 ${date.month}월',
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          if (events.isEmpty) return const SizedBox.shrink();
          return const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: RecordDot(),
            ),
          );
        },
        headerTitleBuilder: (context, day) => GestureDetector(
          onTap: _enterYearView,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${day.year}년 ${day.month}월',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
      enabledDayPredicate: (day) => !_isAfterToday(day),
    );
  }

  Widget _buildYearView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = _today;
    final minYear = _firstDay.year;
    final maxYear = today.year;
    final canGoBack = _yearViewYear > minYear;
    final canGoForward = _yearViewYear < maxYear;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Year navigation header
        Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.chevron_left,
                color: canGoBack ? null : colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              onPressed: canGoBack
                  ? () => setState(() => _yearViewYear--)
                  : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$_yearViewYear년',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: canGoForward ? null : colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              onPressed: canGoForward
                  ? () => setState(() => _yearViewYear++)
                  : null,
            ),
          ],
        ),
        // 4×3 month grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 2.0,
          ),
          itemCount: 12,
          itemBuilder: (context, i) {
            final month = i + 1;
            final isDisabled = _yearViewYear == today.year && month > today.month;
            final isCurrent = _yearViewYear == _focusedDay.year && month == _focusedDay.month;

            return GestureDetector(
              onTap: isDisabled ? null : () => _onMonthTapped(month),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isCurrent ? colorScheme.primary : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$month월',
                  style: TextStyle(
                    color: isDisabled
                        ? colorScheme.onSurface.withValues(alpha: 0.3)
                        : isCurrent
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
