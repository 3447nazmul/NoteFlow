import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Note Model
///
/// Compatible with both Firestore (toMap / fromMap) and Hive
/// (hand-written TypeAdapter registered as typeId 0).
///
/// Hive adapter is at the bottom of this file.  It is registered
/// in main.dart via Hive.registerAdapter(NoteAdapter()).
///
/// Phase 17 additions:
///   • folderId   — folder assignment (null = unfiled)
///   • isPinned   — sticky top-of-list
///   • isDeleted  — soft-delete (trash bin)
///   • deletedAt  — when moved to trash (30-day purge)
///   • checklist  — Notion-style [{text, checked}] items
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Core data model representing a single note, including its content, metadata, and sync status.
class Note {
  String id; // unique ID (UUID)
  String userId; // Firebase user ID
  String title; // note title
  String body; // note full text
  List<String> tags; // AI-generated tags
  String summary; // AI-generated summary
  bool isSynced; // true if saved to Firestore
  DateTime createdAt; // creation timestamp
  DateTime updatedAt; // last edit timestamp

  // ── Phase 17 fields ──
  String? folderId; // folder this note belongs to (null = root)
  bool isPinned; // pinned to top of list
  bool isDeleted; // soft-deleted (in trash)
  DateTime? deletedAt; // when the note was trashed
  List<Map<String, dynamic>> checklist; // [{text: String, checked: bool}]
  List<Map<String, String>> attachments; // [{id, path, name, type}]

  Note({
    String? id,
    this.userId = '',
    this.title = '',
    this.body = '',
    List<String>? tags,
    this.summary = '',
    this.isSynced = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.folderId,
    this.isPinned = false,
    this.isDeleted = false,
    this.deletedAt,
    List<Map<String, dynamic>>? checklist,
    List<Map<String, String>>? attachments,
  }) : id = id ?? const Uuid().v4(),
       tags = tags ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       checklist = checklist ?? [],
       attachments = attachments ?? [];

  // ─── Convenience Getters ───

  /// Shortened preview of the note body (first 120 chars).
  // AI NOTE: Generates a short preview snippet of the note body for UI lists.
  String get preview {
    if (body.isEmpty) return '';
    return body.length > 120 ? '${body.substring(0, 120)}…' : body;
  }

  /// Display-friendly title (falls back to "Untitled Note").
  // AI NOTE: Returns the note title or a default fallback if empty.
  String get displayTitle => title.isEmpty ? 'Untitled Note' : title;

  /// Days remaining before permanent deletion from trash.
  // AI NOTE: Calculates the number of days remaining before a trashed note is permanently deleted.
  int? get daysUntilPurge {
    if (!isDeleted || deletedAt == null) return null;
    final elapsed = DateTime.now().difference(deletedAt!).inDays;
    return (30 - elapsed).clamp(0, 30);
  }

  /// Whether this trashed note has expired (> 30 days).
  // AI NOTE: Checks if a trashed note has exceeded the 30-day retention period.
  bool get isExpiredTrash {
    if (!isDeleted || deletedAt == null) return false;
    return DateTime.now().difference(deletedAt!).inDays >= 30;
  }

  // ─── Copy ───

  /// Create a copy with optional overrides.
  // AI NOTE: Creates a copy of the note with selectively updated fields.
  Note copyWith({
    String? userId,
    String? title,
    String? body,
    List<String>? tags,
    String? summary,
    bool? isSynced,
    DateTime? updatedAt,
    String? folderId,
    bool clearFolder = false,
    bool? isPinned,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    List<Map<String, dynamic>>? checklist,
    List<Map<String, String>>? attachments,
  }) {
    return Note(
      id: id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? List.from(this.tags),
      summary: summary ?? this.summary,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      isPinned: isPinned ?? this.isPinned,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      checklist:
          checklist ??
          List<Map<String, dynamic>>.from(
            this.checklist.map((m) => Map<String, dynamic>.from(m)),
          ),
      attachments:
          attachments ??
          List<Map<String, String>>.from(
            this.attachments.map((m) => Map<String, String>.from(m)),
          ),
    );
  }

  // ─── Firestore Serialisation ───

  /// Serialise to a Map for Firestore / Hive storage.
  // AI NOTE: Serializes the note into a Map for comprehensive local storage (Hive).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'tags': tags,
      'summary': summary,
      'isSynced': isSynced,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'folderId': folderId,
      'isPinned': isPinned,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'checklist': checklist,
      'attachments': attachments,
    };
  }

  /// Serialise only text-based fields for Firestore sync.
  /// Media paths and trash state are excluded.
  // AI NOTE: Serializes the note into a Map for cloud storage (Firestore), excluding local-only fields like trash state.
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'tags': tags,
      'summary': summary,
      'isSynced': true,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'folderId': folderId,
      'isPinned': isPinned,
      'checklist': checklist,
      // NOTE: isDeleted/deletedAt are NOT synced — trash is local-only.
      // NOTE: Media files (OCR images, voice recordings) are stored
      //       strictly in local device storage to minimize cloud costs.
    };
  }

  /// Deserialise from a Firestore / Hive Map.
  // AI NOTE: Deserializes a Map from Firestore or Hive into a Note object.
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String? ?? const Uuid().v4(),
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      summary: map['summary'] as String? ?? '',
      isSynced: map['isSynced'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.now(),
      folderId: map['folderId'] as String?,
      isPinned: map['isPinned'] as bool? ?? false,
      isDeleted: map['isDeleted'] as bool? ?? false,
      deletedAt: map['deletedAt'] != null
          ? DateTime.parse(map['deletedAt'] as String)
          : null,
      checklist:
          (map['checklist'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      attachments:
          (map['attachments'] as List?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ??
          [],
    );
  }

  @override
  String toString() => 'Note(id: $id, title: $displayTitle)';
}

/// ──────────────────────────────────────────────────────────────
/// Hive TypeAdapter for Note  (typeId: 0)
///
/// This is the hand-written equivalent of what build_runner /
/// hive_generator would produce.  It maps each field to a binary
/// index so Hive can read and write Note objects directly.
///
/// Field indices:
///   0: id          1: userId       2: title        3: body
///   4: tags        5: summary      6: isSynced     7: createdAt
///   8: updatedAt   9: folderId    10: isPinned    11: isDeleted
///  12: deletedAt  13: checklist   14: attachments
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Custom Hive TypeAdapter for binary serialization/deserialization of Note objects.
class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = 0;

  @override
  Note read(BinaryReader reader) {
    final int numFields = reader.readByte();
    final Map<int, dynamic> fields = {};
    for (int i = 0; i < numFields; i++) {
      final int key = reader.readByte();
      final dynamic value = reader.read();
      fields[key] = value;
    }

    // Decode checklist from List<Map> stored as List<dynamic>
    List<Map<String, dynamic>> checklist = [];
    if (fields[13] != null) {
      final raw = fields[13] as List;
      checklist = raw.map((e) {
        if (e is Map) {
          return Map<String, dynamic>.from(e);
        }
        return <String, dynamic>{};
      }).toList();
    }

    List<Map<String, String>> attachments = [];
    if (fields[14] != null) {
      final raw = fields[14] as List;
      attachments = raw.map((e) {
        if (e is Map) {
          return e.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
        return <String, String>{};
      }).toList();
    }

    return Note(
      id: fields[0] as String? ?? '',
      userId: fields[1] as String? ?? '',
      title: fields[2] as String? ?? '',
      body: fields[3] as String? ?? '',
      tags: (fields[4] as List?)?.cast<String>() ?? [],
      summary: fields[5] as String? ?? '',
      isSynced: fields[6] as bool? ?? false,
      createdAt: fields[7] != null
          ? DateTime.fromMillisecondsSinceEpoch(fields[7] as int)
          : DateTime.now(),
      updatedAt: fields[8] != null
          ? DateTime.fromMillisecondsSinceEpoch(fields[8] as int)
          : DateTime.now(),
      folderId: fields[9] as String?,
      isPinned: fields[10] as bool? ?? false,
      isDeleted: fields[11] as bool? ?? false,
      deletedAt: fields[12] != null
          ? DateTime.fromMillisecondsSinceEpoch(fields[12] as int)
          : null,
      checklist: checklist,
      attachments: attachments,
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer
      ..writeByte(15) // number of fields
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.body)
      ..writeByte(4)
      ..write(obj.tags)
      ..writeByte(5)
      ..write(obj.summary)
      ..writeByte(6)
      ..write(obj.isSynced)
      ..writeByte(7)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(8)
      ..write(obj.updatedAt.millisecondsSinceEpoch)
      ..writeByte(9)
      ..write(obj.folderId)
      ..writeByte(10)
      ..write(obj.isPinned)
      ..writeByte(11)
      ..write(obj.isDeleted)
      ..writeByte(12)
      ..write(obj.deletedAt?.millisecondsSinceEpoch)
      ..writeByte(13)
      ..write(obj.checklist)
      ..writeByte(14)
      ..write(obj.attachments);
  }
}
