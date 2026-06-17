import 'package:flutter/material.dart';
import '../../core/models/date_key.dart';
import '../../core/models/time_block.dart';

/// Default colour for a "has record" dot shown under a day number.
/// Injected from one place so it can later be swapped for the day's dominant
/// category colour without touching every call site.
const Color kRecordDotColor = Color(0xFF9E9E9E);

/// Set of dates that have at least one time block.
Set<DateKey> recordDatesOf(List<TimeBlock> blocks) =>
    blocks.map((b) => b.date).toSet();

/// Small filled circle marking a day that has records.
class RecordDot extends StatelessWidget {
  const RecordDot({
    super.key,
    this.color = kRecordDotColor,
    this.size = 4,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
