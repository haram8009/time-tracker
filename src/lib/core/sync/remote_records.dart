// Plain data carriers for Supabase upserts. Field names mirror the SQL
// contract columns in `supabase/migrations/202606170001_cloud_sync_contract.sql`.

class RemoteCategory {
  final String id; // uuid
  final String ownerId;
  final String name;
  final String colorHex;
  final bool isPreset;
  final bool isHidden;
  final int sortOrder;
  final String updatedAt; // ISO-8601 UTC
  final String? deletedAt;

  const RemoteCategory({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.colorHex,
    required this.isPreset,
    required this.isHidden,
    required this.sortOrder,
    required this.updatedAt,
    this.deletedAt,
  });

  factory RemoteCategory.fromMap(Map<String, Object?> map) => RemoteCategory(
        id: map['id'] as String,
        ownerId: map['owner_id'] as String,
        name: map['name'] as String,
        colorHex: map['color_hex'] as String,
        isPreset: map['is_preset'] as bool,
        isHidden: map['is_hidden'] as bool,
        sortOrder: (map['sort_order'] as num).toInt(),
        updatedAt: map['updated_at'] as String,
        deletedAt: map['deleted_at'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'color_hex': colorHex,
        'is_preset': isPreset,
        'is_hidden': isHidden,
        'sort_order': sortOrder,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };
}

class RemoteTimeBlock {
  final String id; // uuid
  final String ownerId;
  final String categoryId; // remote category uuid
  final String date; // yyyy-MM-dd
  final int startMinute;
  final int endMinute;
  final String? note;
  final String updatedAt;
  final String? deletedAt;

  const RemoteTimeBlock({
    required this.id,
    required this.ownerId,
    required this.categoryId,
    required this.date,
    required this.startMinute,
    required this.endMinute,
    required this.note,
    required this.updatedAt,
    this.deletedAt,
  });

  factory RemoteTimeBlock.fromMap(Map<String, Object?> map) => RemoteTimeBlock(
        id: map['id'] as String,
        ownerId: map['owner_id'] as String,
        categoryId: map['category_id'] as String,
        date: map['date'] as String,
        startMinute: (map['start_minute'] as num).toInt(),
        endMinute: (map['end_minute'] as num).toInt(),
        note: map['note'] as String?,
        updatedAt: map['updated_at'] as String,
        deletedAt: map['deleted_at'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'owner_id': ownerId,
        'category_id': categoryId,
        'date': date,
        'start_minute': startMinute,
        'end_minute': endMinute,
        'note': note,
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };
}

class RemoteSettings {
  final String ownerId;
  final bool notificationEnabled;
  final int sleepStartMinute;
  final int sleepEndMinute;
  final String updatedAt;

  const RemoteSettings({
    required this.ownerId,
    required this.notificationEnabled,
    required this.sleepStartMinute,
    required this.sleepEndMinute,
    required this.updatedAt,
  });

  factory RemoteSettings.fromMap(Map<String, Object?> map) => RemoteSettings(
        ownerId: map['owner_id'] as String,
        notificationEnabled: map['notification_enabled'] as bool,
        sleepStartMinute: (map['sleep_start_minute'] as num).toInt(),
        sleepEndMinute: (map['sleep_end_minute'] as num).toInt(),
        updatedAt: map['updated_at'] as String,
      );

  Map<String, Object?> toMap() => {
        'owner_id': ownerId,
        'notification_enabled': notificationEnabled,
        'sleep_start_minute': sleepStartMinute,
        'sleep_end_minute': sleepEndMinute,
        'updated_at': updatedAt,
      };
}
