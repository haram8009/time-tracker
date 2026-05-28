class Category {
  final int? id;
  final String name;
  final String colorHex; // e.g. "#FF5733"
  final bool isPreset;
  final bool isHidden;

  const Category({
    this.id,
    required this.name,
    required this.colorHex,
    this.isPreset = false,
    this.isHidden = false,
  });

  Category copyWith({
    int? id,
    String? name,
    String? colorHex,
    bool? isPreset,
    bool? isHidden,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      isPreset: isPreset ?? this.isPreset,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'colorHex': colorHex,
      'isPreset': isPreset ? 1 : 0,
      'isHidden': isHidden ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      colorHex: map['colorHex'] as String,
      isPreset: (map['isPreset'] as int) == 1,
      isHidden: (map['isHidden'] as int?) == 1,
    );
  }

  @override
  String toString() =>
      'Category(id: $id, name: $name, colorHex: $colorHex, isPreset: $isPreset, isHidden: $isHidden)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.colorHex == colorHex &&
        other.isPreset == isPreset &&
        other.isHidden == isHidden;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, colorHex, isPreset, isHidden);
}
