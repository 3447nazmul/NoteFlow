import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../features/notes/models/note_model.dart';
import '../features/notes/models/folder_model.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Firebase Firestore Service
///
/// Manages cloud persistence for notes and folders.
///
/// Firestore structure:
///   users/{userId}/notes/{noteId}
///   users/{userId}/folders/{folderId}
///
/// STORAGE POLICY:
///   • Only text-based data is synced (title, body, tags, summary,
///     folderId, isPinned, checklist).
///   • Media files (OCR images, voice recordings) are stored
///     strictly in local device storage.
///   • Trash state (isDeleted/deletedAt) is NOT synced — local only.
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Service class to manage cloud persistence of notes and folders using Firebase Firestore.
class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Reference to a user's notes sub-collection.
  // AI NOTE: Returns a Firestore reference to the user's notes sub-collection.
  CollectionReference<Map<String, dynamic>> _notesRef(String userId) {
    return _db.collection('users').doc(userId).collection('notes');
  }

  /// Reference to a user's folders sub-collection.
  // AI NOTE: Returns a Firestore reference to the user's folders sub-collection.
  CollectionReference<Map<String, dynamic>> _foldersRef(String userId) {
    return _db.collection('users').doc(userId).collection('folders');
  }

  // ─── Create ───

  /// Saves a new note to Firestore under  users/{userId}/notes/{noteId}.
  /// Uses `set()` so the document ID matches the local note ID.
  /// Uses toFirestoreMap() to exclude local-only fields.
  // AI NOTE: Saves a new note to Firestore, using the local note ID as the document ID.
  Future<void> createNote(Note note) async {
    try {
      final map = note.toFirestoreMap();
      // Store Firestore server timestamp for ordering accuracy
      map['serverUpdatedAt'] = FieldValue.serverTimestamp();

      await _notesRef(note.userId).doc(note.id).set(map);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Firestore createNote failed: $e');
      rethrow;
    }
  }

  // ─── Update ───

  /// Updates an existing note in Firestore.
  /// Uses toFirestoreMap() to exclude trash state and media.
  // AI NOTE: Updates an existing note in Firestore, merging new data with existing data.
  Future<void> updateNote(Note note) async {
    try {
      final map = note.toFirestoreMap();
      map['serverUpdatedAt'] = FieldValue.serverTimestamp();

      await _notesRef(
        note.userId,
      ).doc(note.id).set(map, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Firestore updateNote failed: $e');
      rethrow;
    }
  }

  // ─── Delete ───

  /// Deletes a note from Firestore by its ID.
  // AI NOTE: Permanently deletes a note document from Firestore.
  Future<void> deleteNote(String userId, String noteId) async {
    try {
      await _notesRef(userId).doc(noteId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Firestore deleteNote failed: $e');
      rethrow;
    }
  }

  // ─── Real-time Stream ───

  /// Returns a real-time stream of all notes for the given user,
  /// ordered by updatedAt descending (newest first).
  // AI NOTE: Returns a real-time stream of all user notes from Firestore, ordered by most recently updated.
  Stream<List<Note>> streamNotes(String userId) {
    return _notesRef(
      userId,
    ).orderBy('updatedAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Note.fromMap(doc.data());
      }).toList();
    });
  }

  // ─── Single Read ───

  /// Fetches a single note by ID from Firestore.
  /// Returns null if the note doesn't exist.
  // AI NOTE: Fetches a single note by its ID from Firestore.
  Future<Note?> getNoteById(String userId, String noteId) async {
    try {
      final doc = await _notesRef(userId).doc(noteId).get();
      if (doc.exists && doc.data() != null) {
        return Note.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Firestore getNoteById failed: $e');
      return null;
    }
  }

  // ─── Batch Upload (initial sync) ───

  /// Uploads a batch of local notes to Firestore.
  /// Skips trashed notes (trash is local-only).
  // AI NOTE: Uploads a batch of non-trashed local notes to Firestore, typically used for initial sync.
  Future<void> batchUpload(String userId, List<Note> notes) async {
    // Filter out trashed notes — they don't belong in the cloud
    final syncable = notes.where((n) => !n.isDeleted).toList();
    if (syncable.isEmpty) return;

    try {
      final batch = _db.batch();

      for (final note in syncable) {
        final map = note
            .copyWith(userId: userId, isSynced: true)
            .toFirestoreMap();
        map['serverUpdatedAt'] = FieldValue.serverTimestamp();

        final docRef = _notesRef(userId).doc(note.id);
        batch.set(docRef, map, SetOptions(merge: true));
      }

      await batch.commit();
      if (kDebugMode) {
        debugPrint('✅ Batch-uploaded ${syncable.length} notes to Firestore');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Firestore batchUpload failed: $e');
      rethrow;
    }
  }

  // ─── Fetch All (one-time) ───

  /// Fetches all notes for a user as a one-time read.
  // AI NOTE: Fetches all notes for a user as a one-time read without setting up a real-time stream.
  Future<List<Note>> fetchAllNotes(String userId) async {
    try {
      final snapshot = await _notesRef(
        userId,
      ).orderBy('updatedAt', descending: true).get();

      return snapshot.docs.map((doc) {
        return Note.fromMap(doc.data());
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Firestore fetchAllNotes failed: $e');
      return [];
    }
  }

  // ─── Folder Sync ───

  /// Syncs a folder to Firestore.
  // AI NOTE: Creates or updates a folder in Firestore.
  Future<void> syncFolder(String userId, Folder folder) async {
    try {
      final map = folder.toMap();
      map['userId'] = userId;
      await _foldersRef(userId).doc(folder.id).set(map);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Firestore syncFolder failed: $e');
    }
  }

  /// Deletes a folder from Firestore.
  // AI NOTE: Permanently deletes a folder document from Firestore.
  Future<void> deleteCloudFolder(String userId, String folderId) async {
    try {
      await _foldersRef(userId).doc(folderId).delete();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Firestore deleteFolder failed: $e');
    }
  }

  /// Fetches all folders for a user.
  // AI NOTE: Fetches all folders for a user from Firestore and sorts them by order.
  Future<List<Folder>> fetchAllFolders(String userId) async {
    try {
      final snapshot = await _foldersRef(userId).get();
      return snapshot.docs.map((doc) => Folder.fromMap(doc.data())).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Firestore fetchAllFolders failed: $e');
      return [];
    }
  }
}
