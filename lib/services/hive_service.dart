import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/notes/models/note_model.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Hive Local Storage Service
///
/// Manages offline-first note persistence using a typed Hive box.
/// The NoteAdapter (typeId 0) is registered in main.dart before
/// this service is used.
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Service class managing offline-first persistence of notes using Hive.
class HiveService {
  static const String _boxName = 'notes_box';
  Box<Note>? _box;

  // ─── Init ───

  /// Opens the typed Hive box on app start.
  /// Must be called once after Hive.initFlutter() and
  /// Hive.registerAdapter(NoteAdapter()).
  // AI NOTE: Initializes the Hive box for notes, must be called at startup.
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<Note>(_boxName);
    if (kDebugMode) {
      debugPrint('📦 Hive notes box opened (${_box!.length} notes)');
    }
  }

  /// Returns the open box, opening it if needed.
  // AI NOTE: Helper method to ensure the Hive box is open before operations.
  Future<Box<Note>> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Note>(_boxName);
    return _box!;
  }

  // ─── Save ───

  /// Saves a new note to the local Hive box.
  // AI NOTE: Saves a new note object into the local Hive box.
  Future<void> saveNote(Note note) async {
    final box = await _openBox();
    await box.put(note.id, note);
  }

  // ─── Update ───

  /// Updates an existing note in the local Hive box.
  /// Identical to saveNote (Hive put overwrites by key).
  // AI NOTE: Updates an existing note in the Hive box.
  Future<void> updateNote(Note note) async {
    final box = await _openBox();
    await box.put(note.id, note);
  }

  // ─── Delete ───

  /// Removes a note from the local Hive box.
  // AI NOTE: Removes a note from the local Hive box.
  Future<void> deleteNote(String noteId) async {
    final box = await _openBox();
    await box.delete(noteId);
  }

  // ─── Read All ───

  /// Returns all notes from the local box.
  // AI NOTE: Retrieves all notes stored locally in Hive.
  Future<List<Note>> getAllNotes() async {
    try {
      final box = await _openBox();
      return box.values.toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Hive getAllNotes failed: $e');
      return [];
    }
  }

  // ─── Read One ───

  /// Returns a single note by ID, or null if not found.
  // AI NOTE: Retrieves a single note by its ID from Hive.
  Future<Note?> getNoteById(String noteId) async {
    final box = await _openBox();
    return box.get(noteId);
  }

  // ─── Helpers ───

  /// Returns all notes where isSynced == false.
  // AI NOTE: Retrieves all local notes that have not yet been synced to the cloud.
  Future<List<Note>> getUnsyncedNotes() async {
    final box = await _openBox();
    return box.values.where((n) => !n.isSynced).toList();
  }

  /// Marks a note as synced in the local box.
  // AI NOTE: Updates a note's local state to mark it as successfully synced.
  Future<void> markSynced(String noteId) async {
    final box = await _openBox();
    final note = box.get(noteId);
    if (note != null) {
      await box.put(noteId, note.copyWith(isSynced: true));
    }
  }
}
