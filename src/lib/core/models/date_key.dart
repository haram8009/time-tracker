class DateKey {
  const DateKey(this.year, this.month, this.day);

  factory DateKey.today() {
    final now = DateTime.now();
    return DateKey(now.year, now.month, now.day);
  }

  factory DateKey.fromDateTime(DateTime dt) {
    return DateKey(dt.year, dt.month, dt.day);
  }

  factory DateKey.fromPage(int page, DateKey epoch) {
    final dt = epoch.toDateTime().add(Duration(days: page));
    return DateKey.fromDateTime(dt);
  }

  factory DateKey.fromDbString(String s) {
    final parts = s.split('-');
    return DateKey(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  static const DateKey appEpoch = DateKey(2020, 1, 1);

  final int year;
  final int month;
  final int day;

  int toPage(DateKey epoch) {
    return toDateTime().difference(epoch.toDateTime()).inDays;
  }

  String toDbString() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateKey yesterday() {
    return add(const Duration(days: -1));
  }

  DateKey add(Duration duration) {
    return DateKey.fromDateTime(toDateTime().add(duration));
  }

  bool isBefore(DateKey other) {
    if (year != other.year) return year < other.year;
    if (month != other.month) return month < other.month;
    return day < other.day;
  }

  bool isAfter(DateKey other) {
    if (year != other.year) return year > other.year;
    if (month != other.month) return month > other.month;
    return day > other.day;
  }

  DateTime toDateTime() {
    return DateTime(year, month, day);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DateKey &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toDbString();
}
