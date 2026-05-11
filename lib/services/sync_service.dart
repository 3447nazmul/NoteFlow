import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../features/notes/models/note_model.dart';
import 'firebase_service.dart';
import 'hive_service.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Sync Service
///
/// Orchestrates offline-first sync between Hive (local) and
/// Firestore (cloud).
///
/// Strategy:
///  • When ONLINE  → save to both Hive + Firestore, isSynced = true
///  • When OFFLINE → save to Hive only, isSynced = false
///  • When connection returns → auto-push unsynced queue
///  • Firestore stream → writes incoming cloud changes to Hive
///
/// STORAGE POLICY (Phase 17):
///  ┌─────────────────────┬──────────────────────────────────┐
///  │ Firestore (Cloud)   │ Local-Only (Hive / Device)       │
///  ├─────────────────────┼──────────────────────────────────┤
///  │ title, body, tags   │ isDeleted, deletedAt (trash)    │
///  │ summary, folderId   │ OCR images (future)             │
///  │ isPinned, checklist  │ Voice recordings (future)       │
///  │ createdAt, updatedAt│ Media file paths (future)       │
///  │ userId, isSynced    │ Local cache / thumbnails        │
///  └─────────────────────┴──────────────────────────────────┘
///
///  • Note.toFirestoreMap() handles the text-only extraction
///  • Firebase batch upload skips trashed notes entirely
///  • Media files NEVER leave the device (stored in app dir)
///
/// Exposes [isOnline] and [onlineStream] so the UI can show
/// an offline banner.
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Central service orchestrating offline-first synchronization between local Hive and cloud Firestore.
class SyncService extends ChangeNotifier {
  final HiveService _hive;
  final FirebaseService _firebase;
  final Connectivity _connectivity = Connectivity();

  bool _isOnline = true;
  bool _isSyncing = false;
  String? _currentUserId;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<List<Note>>? _firestoreSub;

  SyncService({
    required HiveService hiveService,
    required FirebaseService firebaseService,
  }) : _hive = hiveService,
       _firebase = firebaseService {
    _listenConnectivity();
  }

  // ─── Getters ───

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  // ─── Connectivity Listener ───

  // AI NOTE: Sets up a listener for network connectivity changes to trigger sync when online.
  void _listenConnectivity() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final wasOffline = !_isOnline;
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      notifyListeners();

      // Connection restored → flush the sync queue
      if (wasOffline && _isOnline && _currentUserId != null) {
        if (kDebugMode) debugPrint('🌐 Connection restored — syncing queue…');
        syncUnsyncedNotes(_currentUserId!);
      }
    });
  }

  /// Check connectivity once (e.g. at startup).
  // AI NOTE: Performs a one-time check of current network connectivity.
  Future<void> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    notifyListeners();
  }

  // ─── Set Active User ───

  /// Call this when the user signs in.  Starts the Firestore
  /// listener and runs an initial sync.
  // AI NOTE: Sets the active user, triggering initial sync and real-time Firestore listeners.
  Future<void> setUser(String userId) async {
    _currentUserId = userId;
    await checkConnectivity();

    if (_isOnline) {
      // Push any local-only notes to Firestore
      await syncUnsyncedNotes(userId);
      // Start listening to Firestore for real-time cloud changes
      _startFirestoreListener(userId);
    }
  }

  /// Call this when the user signs out.
  // AI NOTE: Clears the active user and cancels Firestore listeners (used on sign-out).
  void clearUser() {
    _currentUserId = null;
    _firestoreSub?.cancel();
    _firestoreSub = null;
  }

  // ─── CRUD (Offline-First) ───

  /// Creates a note: always saves to Hive, pushes to Firestore
  /// if online.
  // AI NOTE: Creates a note locally in Hive, and pushes it to Firestore if online.
  Future<Note> createNote(Note note) async {
    if (_isOnline && _currentUserId != null) {
      // Online → save to both
      final synced = note.copyWith(userId: _currentUserId!, isSynced: true);
      await _hive.saveNote(synced);
      try {
        await _firebase.createNote(synced);
      } catch (_) {
        // Firestore failed → mark unsynced locally
        await _hive.saveNote(synced.copyWith(isSynced: false));
        return synced.copyWith(isSynced: false);
      }
      return synced;
    } else {
      // Offline → Hive only, isSynced = false
      final local = note.copyWith(
        userId: _currentUserId ?? '',
        isSynced: false,
      );
      await _hive.saveNote(local);
      return local;
    }
  }

  /// Updates a note: always saves to Hive, pushes to Firestore
  /// if online. Trashed notes are NOT synced to cloud.
  // AI NOTE: Updates a note locally in Hive, and pushes it to Firestore if online (skips trashed notes).
  Future<Note> updateNote(Note note) async {
    final updated = note.copyWith(updatedAt: DateTime.now());

    // Trashed notes stay local-only — don't push to Firestore
    if (updated.isDeleted) {
      final local = updated.copyWith(isSynced: false);
      await _hive.updateNote(local);
      return local;
    }

    if (_isOnline && _currentUserId != null) {
      final synced = updated.copyWith(isSynced: true);
      await _hive.updateNote(synced);
      try {
        await _firebase.updateNote(synced);
      } catch (_) {
        await _hive.updateNote(synced.copyWith(isSynced: false));
        return synced.copyWith(isSynced: false);
      }
      return synced;
    } else {
      final local = updated.copyWith(isSynced: false);
      await _hive.updateNote(local);
      return local;
    }
  }

  /// Deletes a note: always removes from Hive, removes from
  /// Firestore if online.
  // AI NOTE: Deletes a note locally from Hive, and removes it from Firestore if online.
  Future<void> deleteNote(String noteId) async {
    await _hive.deleteNote(noteId);

    if (_isOnline && _currentUserId != null) {
      try {
        await _firebase.deleteNote(_currentUserId!, noteId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Firestore delete failed (will not retry): $e');
        }
      }
    }
  }

  /// Returns all notes from local Hive storage.
  // AI NOTE: Retrieves all notes from local Hive storage.
  Future<List<Note>> getAllNotes() async {
    return _hive.getAllNotes();
  }

  /// Returns a single note from local Hive storage.
  // AI NOTE: Retrieves a single note from local Hive storage by ID.
  Future<Note?> getNoteById(String noteId) async {
    return _hive.getNoteById(noteId);
  }

  // ─── Sync Queue ───

  /// Pushes all unsynced Hive notes to Firestore, then marks
  /// them as synced locally.
  // AI NOTE: Pushes any locally modified, unsynced notes to Firestore.
  Future<void> syncUnsyncedNotes(String userId) async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      final unsynced = await _hive.getUnsyncedNotes();
      if (unsynced.isEmpty) {
        if (kDebugMode) debugPrint('✅ Nothing to sync');
        _isSyncing = false;
        notifyListeners();
        return;
      }

      if (kDebugMode) debugPrint('🔄 Syncing ${unsynced.length} notes…');

      // Set userId on all notes (may be empty if created while signed out)
      final toSync = unsynced
          .map((n) => n.copyWith(userId: userId, isSynced: true))
          .toList();

      await _firebase.batchUpload(userId, toSync);

      // Mark each as synced in Hive
      for (final note in toSync) {
        await _hive.markSynced(note.id);
      }

      if (kDebugMode) debugPrint('✅ Synced ${toSync.length} notes');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ─── Firestore Listener ───

  /// Listens to the user's Firestore notes collection and
  /// mirrors every change into Hive so local data stays fresh.
  // AI NOTE: Starts a real-time listener on Firestore to mirror cloud changes into local Hive storage.
  void _startFirestoreListener(String userId) {
    _firestoreSub?.cancel();

    _firestoreSub = _firebase
        .streamNotes(userId)
        .listen(
          (cloudNotes) async {
            for (final cloudNote in cloudNotes) {
              // Write each cloud note into Hive (overwrites local copy)
              await _hive.saveNote(cloudNote.copyWith(isSynced: true));
            }
            if (kDebugMode) {
              debugPrint(
                '☁️ Firestore listener: ${cloudNotes.length} notes mirrored to Hive',
              );
            }
          },
          onError: (e) {
            if (kDebugMode) debugPrint('⚠️ Firestore stream error: $e');
          },
        );
  }

  // ─── Initial Sync (sign-in) ───

  /// Called once after sign-in to pull all cloud notes into Hive
  /// and push any local-only notes to Firestore.
  // AI NOTE: Performs a complete bidirectional sync (pull from cloud, push local changes) upon sign-in.
  Future<void> performInitialSync(String userId) async {
    if (!_isOnline) return;

    try {
      // 1. Pull cloud → Hive
      final cloudNotes = await _firebase.fetchAllNotes(userId);
      for (final note in cloudNotes) {
        await _hive.saveNote(note.copyWith(isSynced: true));
      }
      if (kDebugMode) {
        debugPrint('⬇️ Pulled ${cloudNotes.length} notes from cloud');
      }

      // 2. Push unsynced local → Firestore
      await syncUnsyncedNotes(userId);

      // 3. Start real-time listener
      _startFirestoreListener(userId);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Initial sync failed: $e');
    }
  }

  // ─── Cleanup ───

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _firestoreSub?.cancel();
    super.dispose();
  }
}
