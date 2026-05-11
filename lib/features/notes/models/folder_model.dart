import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Folder Model
///
/// Represents a user-created folder for organizing notes.
/// Persisted locally via Hive (typeId: 1) and synced to
/// Firestore under users/{userId}/folders/{folderId}.
///
/// Flat structure (no nested sub-folders in V1).
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Data model representing a user-created folder for organizing notes.
class Folder {
  String id; // unique ID (UUID)
  String name; // display name
  String userId; // owner
  int sortOrder; // manual ordering (lower = first)
  DateTime createdAt;

  Folder({
    String? id,
    this.name = 'New Folder',
    this.userId = '',
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  // AI NOTE: Creates a copy of the folder with selectively updated fields.
  Folder copyWith({String? name, String? userId, int? sortOrder}) {
    return Folder(
      id: id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }

  // AI NOTE: Serializes the folder object into a Map for Firestore or Hive storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'userId': userId,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // AI NOTE: Deserializes a Map from Firestore or Hive into a Folder object.
  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as String? ?? const Uuid().v4(),
      name: map['name'] as String? ?? 'Untitled Folder',
      userId: map['userId'] as String? ?? '',
      sortOrder: map['sortOrder'] as int? ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  @override
  String toString() => 'Folder(id: $id, name: $name)';
}

/// ──────────────────────────────────────────────────────────────
/// Hive TypeAdapter for Folder  (typeId: 1)
///
/// Field indices:
///   0: id    1: name    2: userId    3: sortOrder    4: createdAt
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Custom Hive TypeAdapter for binary serialization/deserialization of Folder objects.
class FolderAdapter extends TypeAdapter<Folder> {
  @override
  final int typeId = 1;

  @override
  Folder read(BinaryReader reader) {
    final int numFields = reader.readByte();
    final Map<int, dynamic> fields = {};
    for (int i = 0; i < numFields; i++) {
      final int key = reader.readByte();
      final dynamic value = reader.read();
      fields[key] = value;
    }

    return Folder(
      id: fields[0] as String? ?? '',
      name: fields[1] as String? ?? 'Untitled Folder',
      userId: fields[2] as String? ?? '',
      sortOrder: fields[3] as int? ?? 0,
      createdAt: fields[4] != null
          ? DateTime.fromMillisecondsSinceEpoch(fields[4] as int)
          : DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, Folder obj) {
    writer
      ..writeByte(5) // number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.sortOrder)
      ..writeByte(4)
      ..write(obj.createdAt.millisecondsSinceEpoch);
  }
}
