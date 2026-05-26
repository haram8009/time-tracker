class Category {
  final int? id;
  final String name;
  final String colorHex; // e.g. "#FF5733"
  final bool isPreset;

  const Category({
    this.id,
    required this.name,
    required this.colorHex,
    this.isPreset = false,
  });

  Category copyWith({
    int? id,
    String? name,
    String? colorHex,
    bool? isPreset,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      isPreset: isPreset ?? this.isPreset,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'colorHex': colorHex,
      'isPreset': isPreset ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      colorHex: map['colorHex'] as String,
      isPreset: (map['isPreset'] as int) == 1,
    );
  }

  @override
  String toString() =>
      'Category(id: $id, name: $name, colorHex: $colorHex, isPreset: $isPreset)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.colorHex == colorHex &&
        other.isPreset == isPreset;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, colorHex, isPreset);
}
