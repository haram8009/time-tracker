class TimeBlock {
  final int? id;
  final String date; // "YYYY-MM-DD"
  final int startMinute; // 0-1440, 10분 단위
  final int endMinute; // 0-1440, 10분 단위
  final int categoryId;
  final String? note;

  const TimeBlock({
    this.id,
    required this.date,
    required this.startMinute,
    required this.endMinute,
    required this.categoryId,
    this.note,
  });

  TimeBlock copyWith({
    int? id,
    String? date,
    int? startMinute,
    int? endMinute,
    int? categoryId,
    String? note,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      date: date ?? this.date,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'startMinute': startMinute,
      'endMinute': endMinute,
      'categoryId': categoryId,
      if (note != null) 'note': note,
    };
  }

  factory TimeBlock.fromMap(Map<String, dynamic> map) {
    return TimeBlock(
      id: map['id'] as int?,
      date: map['date'] as String,
      startMinute: map['startMinute'] as int,
      endMinute: map['endMinute'] as int,
      categoryId: map['categoryId'] as int,
      note: map['note'] as String?,
    );
  }

  @override
  String toString() => 'TimeBlock(id: $id, date: $date, '
      'startMinute: $startMinute, endMinute: $endMinute, '
      'categoryId: $categoryId, note: $note)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeBlock &&
        other.id == id &&
        other.date == date &&
        other.startMinute == startMinute &&
        other.endMinute == endMinute &&
        other.categoryId == categoryId &&
        other.note == note;
  }

  @override
  int get hashCode =>
      Object.hash(id, date, startMinute, endMinute, categoryId, note);
}
