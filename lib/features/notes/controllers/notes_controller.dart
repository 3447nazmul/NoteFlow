import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/note_model.dart';
import '../models/folder_model.dart';
import '../../../services/ai_service.dart';
import '../../../services/sync_service.dart';
import '../../../services/folder_service.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Notes Controller
///
/// Central state manager for the notes feature (Provider-based).
///
/// Responsibilities:
///  • In-memory note list with search / filter / sort
///  • CRUD via SyncService (Hive ↔ Firestore, offline-first)
///  • AI features via AiService (summarise, tag, chat, calculate)
///  • Firestore real-time listener that merges cloud changes
///  • Undo-delete with a 5-second grace window
///
/// Phase 17 additions:
///  • Folder filtering (activeFolder)
///  • Pinning (togglePin, pinned section in filteredNotes)
///  • Trash bin (moveToTrash, restore, permanentlyDelete, purge)
///  • Checklist CRUD (updateChecklist, toggleChecklistItem)
///
/// State exposed to the UI:
///  • notesList       — canonical list of all notes
///  • filteredNotes   — notesList filtered + sorted
///  • isLoading       — true during initial load
///  • isSyncing       — true while Firestore sync is in progress
///  • searchQuery     — current search string
///  • activeTag       — filter by a specific tag (or empty)
///  • sortMode        — current sort mode
///  • activeFolder    — filter by folder ID (null = all)
///  • isTrashView     — true when viewing trash
///  • foldersList     — all user folders
/// ──────────────────────────────────────────────────────────────

/// Sort modes available in the UI.
enum SortMode {
  dateModified('Date Modified'),
  dateCreated('Date Created'),
  alphabetical('Alphabetical');

  final String label;
  const SortMode(this.label);
}

// AI NOTE: Core state controller managing the list of notes, folders, and UI states (search, sort, filter).
class NotesController extends ChangeNotifier {
  final SyncService _sync;
  final AiService _ai;
  final FolderService _folderService;

  // ─── State ───

  List<Note> _notesList = [];
  List<Folder> _foldersList = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String _searchQuery = '';
  String _activeTag = '';
  SortMode _sortMode = SortMode.dateModified;

  // Phase 17 state
  String? _activeFolder; // null = "All Notes"
  bool _isTrashView = false;

  // ─── Undo-delete ───

  Note? _pendingDeleteNote;
  Timer? _undoTimer;

  StreamSubscription<List<Note>>? _firestoreSub;

  // ─── Constructor ───

  NotesController({
    required SyncService syncService,
    required AiService aiService,
    required FolderService folderService,
  }) : _sync = syncService,
       _ai = aiService,
       _folderService = folderService {
    loadNotes();
    _loadFolders();
  }

  // ═════════════════════════════════════════════════════════════
  //  Getters
  // ═════════════════════════════════════════════════════════════

  List<Note> get notesList => List.unmodifiable(_notesList);
  List<Folder> get foldersList => List.unmodifiable(_foldersList);
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String get searchQuery => _searchQuery;
  String get activeTag => _activeTag;
  SortMode get sortMode => _sortMode;
  String? get activeFolder => _activeFolder;
  bool get isTrashView => _isTrashView;

  /// Returns all unique tags across all notes (for filter UI).
  List<String> get allTags {
    final tags = <String>{};
    for (final note in _notesList) {
      if (!note.isDeleted) tags.addAll(note.tags);
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  /// Returns notes in the trash.
  List<Note> get trashedNotes {
    return _notesList.where((n) => n.isDeleted).toList()..sort(
      (a, b) =>
          (b.deletedAt ?? b.updatedAt).compareTo(a.deletedAt ?? a.updatedAt),
    );
  }

  /// Returns notes filtered by [searchQuery], [activeTag],
  /// [activeFolder], then sorted by [sortMode].
  /// Pinned notes are always at the top.
  /// Deleted notes are excluded unless viewing trash.
  // AI NOTE: Computes the actively displayed notes by applying folder filters, search query, tag filters, sorting, and pinning rules.
  List<Note> get filteredNotes {
    // If viewing trash, return trashed notes
    if (_isTrashView) return trashedNotes;

    List<Note> result;

    // 0. Exclude deleted notes
    final active = _notesList.where((n) => !n.isDeleted).toList();

    // 1. Filter by folder
    if (_activeFolder != null) {
      result = active.where((n) => n.folderId == _activeFolder).toList();
    } else {
      result = List.from(active);
    }

    // 2. Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((n) {
        return n.title.toLowerCase().contains(q) ||
            n.body.toLowerCase().contains(q) ||
            n.tags.any((t) => t.toLowerCase().contains(q)) ||
            n.summary.toLowerCase().contains(q);
      }).toList();
    }

    // 3. Filter by active tag
    if (_activeTag.isNotEmpty) {
      result = result
          .where(
            (n) =>
                n.tags.any((t) => t.toLowerCase() == _activeTag.toLowerCase()),
          )
          .toList();
    }

    // 4. Sort
    switch (_sortMode) {
      case SortMode.dateModified:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case SortMode.dateCreated:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortMode.alphabetical:
        result.sort(
          (a, b) => a.displayTitle.toLowerCase().compareTo(
            b.displayTitle.toLowerCase(),
          ),
        );
        break;
    }

    // 5. Pin: move pinned notes to top (maintaining sort within each group)
    final pinned = result.where((n) => n.isPinned).toList();
    final unpinned = result.where((n) => !n.isPinned).toList();

    return [...pinned, ...unpinned];
  }

  /// Returns indices where the pinned section ends.
  /// Used by the UI to show a "Pinned" section header.
  int get pinnedCount {
    if (_isTrashView) return 0;
    return filteredNotes.where((n) => n.isPinned).length;
  }

  // ═════════════════════════════════════════════════════════════
  //  Search
  // ═════════════════════════════════════════════════════════════

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════════
  //  Tag Filter
  // ═════════════════════════════════════════════════════════════

  void setActiveTag(String tag) {
    // Toggle: if same tag is tapped again, clear the filter
    if (_activeTag.toLowerCase() == tag.toLowerCase()) {
      _activeTag = '';
    } else {
      _activeTag = tag;
    }
    notifyListeners();
  }

  void clearTagFilter() {
    _activeTag = '';
    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════════
  //  Sort
  // ═════════════════════════════════════════════════════════════

  void setSortMode(SortMode mode) {
    if (_sortMode != mode) {
      _sortMode = mode;
      notifyListeners();
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  Folder Filter
  // ═════════════════════════════════════════════════════════════

  void setActiveFolder(String? folderId) {
    _activeFolder = folderId;
    _isTrashView = false;
    notifyListeners();
  }

  void showTrash() {
    _isTrashView = true;
    _activeFolder = null;
    _activeTag = '';
    _searchQuery = '';
    notifyListeners();
  }

  void showAllNotes() {
    _isTrashView = false;
    _activeFolder = null;
    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════════
  //  Folder CRUD
  // ═════════════════════════════════════════════════════════════

  Future<void> _loadFolders() async {
    _foldersList = await _folderService.getAllFolders();
    notifyListeners();
  }

  // AI NOTE: Creates a new folder.
  Future<Folder> createFolder(String name) async {
    final folder = await _folderService.createFolder(name);
    await _loadFolders();
    return folder;
  }

  Future<void> renameFolder(String folderId, String newName) async {
    await _folderService.renameFolder(folderId, newName);
    await _loadFolders();
  }

  // AI NOTE: Deletes a folder and moves its notes to 'unfiled'.
  Future<void> deleteFolder(String folderId) async {
    // Move all notes in this folder to unfiled
    for (final note in _notesList.where((n) => n.folderId == folderId)) {
      final updated = note.copyWith(clearFolder: true);
      await _sync.updateNote(updated);
    }
    await _folderService.deleteFolder(folderId);

    if (_activeFolder == folderId) _activeFolder = null;
    await _loadFolders();
    await _refreshFromHive();
  }

  // ═════════════════════════════════════════════════════════════
  //  Pinning
  // ═════════════════════════════════════════════════════════════

  Future<void> togglePin(String noteId) async {
    final index = _notesList.indexWhere((n) => n.id == noteId);
    if (index == -1) return;

    final note = _notesList[index];
    final updated = note.copyWith(isPinned: !note.isPinned);
    _notesList[index] = updated;
    notifyListeners();

    await _sync.updateNote(updated);
  }

  // ═════════════════════════════════════════════════════════════
  //  Trash Bin
  // ═════════════════════════════════════════════════════════════

  /// Soft-deletes a note by moving it to trash.
  // AI NOTE: Soft-deletes a note by moving it to the trash bin.
  Future<void> moveToTrash(String noteId) async {
    final index = _notesList.indexWhere((n) => n.id == noteId);
    if (index == -1) return;

    final note = _notesList[index];
    final trashed = note.copyWith(
      isDeleted: true,
      deletedAt: DateTime.now(),
      isPinned: false, // unpin when trashing
    );
    _notesList[index] = trashed;
    notifyListeners();

    await _sync.updateNote(trashed);
  }

  /// Restores a note from trash.
  // AI NOTE: Restores a soft-deleted note from the trash back to active notes.
  Future<void> restoreFromTrash(String noteId) async {
    final index = _notesList.indexWhere((n) => n.id == noteId);
    if (index == -1) return;

    final note = _notesList[index];
    final restored = note.copyWith(isDeleted: false, clearDeletedAt: true);
    _notesList[index] = restored;
    notifyListeners();

    await _sync.updateNote(restored);
  }

  /// Permanently deletes a note (no undo).
  // AI NOTE: Permanently deletes a note without recovery.
  Future<void> permanentlyDelete(String noteId) async {
    _notesList.removeWhere((n) => n.id == noteId);
    notifyListeners();
    await _sync.deleteNote(noteId);
  }

  /// Permanently deletes all notes in trash.
  Future<void> emptyTrash() async {
    final trashed = _notesList.where((n) => n.isDeleted).toList();
    for (final note in trashed) {
      _notesList.removeWhere((n) => n.id == note.id);
      await _sync.deleteNote(note.id);
    }
    notifyListeners();
  }

  /// Purges notes that have been in trash for > 30 days.
  /// Called on app startup.
  Future<void> purgeExpiredTrash() async {
    final expired = _notesList.where((n) => n.isExpiredTrash).toList();
    if (expired.isEmpty) return;

    if (kDebugMode) {
      debugPrint('🗑️ Purging ${expired.length} expired trash notes');
    }
    for (final note in expired) {
      _notesList.removeWhere((n) => n.id == note.id);
      await _sync.deleteNote(note.id);
    }
    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════════
  //  Move to Folder
  // ═════════════════════════════════════════════════════════════

  // AI NOTE: Moves a note into a specific folder or removes it from any folder if null.
  Future<void> moveNoteToFolder(String noteId, String? folderId) async {
    final index = _notesList.indexWhere((n) => n.id == noteId);
    if (index == -1) return;

    final note = _notesList[index];
    final updated = folderId == null
        ? note.copyWith(clearFolder: true)
        : note.copyWith(folderId: folderId);
    _notesList[index] = updated;
    notifyListeners();

    await _sync.updateNote(updated);
  }

  // ═════════════════════════════════════════════════════════════
  //  Checklist
  // ═════════════════════════════════════════════════════════════

  // AI NOTE: Updates the entire checklist for a specific note.
  Future<void> updateChecklist(
    String noteId,
    List<Map<String, dynamic>> items,
  ) async {
    final index = _notesList.indexWhere((n) => n.id == noteId);
    if (index == -1) return;

    final note = _notesList[index];
    final updated = note.copyWith(checklist: items);
    _notesList[index] = updated;
    notifyListeners();

    await _sync.updateNote(updated);
  }

  Future<void> toggleChecklistItem(String noteId, int itemIndex) async {
    final index = _notesList.indexWhere((n) => n.id == noteId);
    if (index == -1) return;

    final note = _notesList[index];
    if (itemIndex < 0 || itemIndex >= note.checklist.length) return;

    final items = List<Map<String, dynamic>>.from(
      note.checklist.map((m) => Map<String, dynamic>.from(m)),
    );
    items[itemIndex]['checked'] =
        !(items[itemIndex]['checked'] as bool? ?? false);

    final updated = note.copyWith(checklist: items);
    _notesList[index] = updated;
    notifyListeners();

    await _sync.updateNote(updated);
  }

  // ═════════════════════════════════════════════════════════════
  //  Load Notes (offline-first)
  // ═════════════════════════════════════════════════════════════

  /// Loads from Hive first for instant display, then starts the
  /// Firestore stream so any cloud changes merge in automatically.
  // AI NOTE: Initial load sequence: loads offline notes from Hive, purges old trash, then starts listening for cloud updates.
  Future<void> loadNotes() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Instant display from local Hive cache
      _notesList = await _sync.getAllNotes();
      _isLoading = false;
      notifyListeners();

      // 2. Purge expired trash
      await purgeExpiredTrash();

      // 3. Start Firestore real-time stream (merges cloud changes)
      _startFirestoreStream();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ NotesController.loadNotes failed: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Listens to the SyncService's Firestore stream and merges
  /// incoming cloud changes into the in-memory list.
  void _startFirestoreStream() {
    _sync.addListener(_onSyncChanged);
  }

  void _onSyncChanged() {
    // When SyncService finishes syncing, refresh in-memory list
    if (!_sync.isSyncing && !_isLoading) {
      _refreshFromHive();
    }
  }

  /// Silently reloads notes from Hive without showing a loader.
  Future<void> _refreshFromHive() async {
    try {
      final fresh = await _sync.getAllNotes();
      _notesList = fresh;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Silent refresh failed: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  Read
  // ═════════════════════════════════════════════════════════════

  /// Returns a note from the in-memory list by ID.
  Note? getNoteById(String id) {
    try {
      return _notesList.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  Create
  // ═════════════════════════════════════════════════════════════

  /// Creates a new empty note, saves to Hive, and syncs to
  /// Firestore if online.
  // AI NOTE: Creates a new empty note and adds it to the top of the list.
  Future<Note> createNote({String userId = ''}) async {
    final note = Note(
      userId: userId,
      folderId: _activeFolder, // Create in the current folder
    );

    // Persist via SyncService (handles Hive + optional Firestore)
    final saved = await _sync.createNote(note);

    // Add to in-memory list at the top
    _notesList.insert(0, saved);
    notifyListeners();

    return saved;
  }

  // ═════════════════════════════════════════════════════════════
  //  Update
  // ═════════════════════════════════════════════════════════════

  /// Updates an existing note, saves to Hive, and syncs to
  /// Firestore if online.
  // AI NOTE: Updates an existing note's content and syncs the changes.
  Future<void> updateNote(Note note) async {
    final updated = await _sync.updateNote(note);

    final index = _notesList.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notesList[index] = updated;
    } else {
      _notesList.insert(0, updated);
    }

    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════════
  //  Delete (with undo support) — legacy, now routes to trash
  // ═════════════════════════════════════════════════════════════

  /// Soft-deletes a note: removes from the UI immediately but
  /// waits 5 seconds before persisting. Returns the deleted note
  /// so the caller can show an undo snackbar.
  Note? deleteNote(String id) {
    // Find the note first
    Note? deletedNote;
    try {
      deletedNote = _notesList.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }

    // Cancel any previous pending delete
    _commitPendingDelete();

    // Stash the note for undo
    _pendingDeleteNote = deletedNote;

    // Optimistic removal from UI
    _notesList.removeWhere((n) => n.id == id);
    notifyListeners();

    // Start 5-second timer — after which the delete is permanent
    _undoTimer = Timer(const Duration(seconds: 5), () {
      _commitPendingDelete();
    });

    return deletedNote;
  }

  /// Restores the last deleted note (undo).
  void undoDelete() {
    if (_pendingDeleteNote == null) return;

    _undoTimer?.cancel();
    _undoTimer = null;

    // Re-insert the note
    _notesList.insert(0, _pendingDeleteNote!);
    _pendingDeleteNote = null;
    notifyListeners();
  }

  /// Commits the pending delete to persistent storage.
  void _commitPendingDelete() {
    _undoTimer?.cancel();
    _undoTimer = null;

    if (_pendingDeleteNote != null) {
      final id = _pendingDeleteNote!.id;
      _pendingDeleteNote = null;
      _sync.deleteNote(id);
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  AI: Summarise Note
  // ═════════════════════════════════════════════════════════════

  Future<String> summariseNote(String noteId) async {
    final note = getNoteById(noteId);
    if (note == null) return 'Note not found.';
    if (note.body.trim().isEmpty) return 'Nothing to summarise.';

    try {
      final summary = await _ai.summariseNote(note.body);
      final updated = note.copyWith(summary: summary);
      await updateNote(updated);
      return summary;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ summariseNote failed: $e');
      return 'Summarisation failed: $e';
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  AI: Tag Note
  // ═════════════════════════════════════════════════════════════

  Future<List<String>> tagNote(String noteId) async {
    final note = getNoteById(noteId);
    if (note == null) return [];

    try {
      final tags = await _ai.generateTags(note.title, note.body);
      final updated = note.copyWith(tags: tags);
      await updateNote(updated);
      return tags;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ tagNote failed: $e');
      return [];
    }
  }

  Future<void> autoTagNoteBackground(String noteId) async {
    final note = getNoteById(noteId);
    if (note == null) return;

    // Only auto-tag if it has substantial content and currently has no tags
    if (note.body.length < 50 || note.tags.isNotEmpty) return;

    try {
      final tags = await _ai.generateTags(note.title, note.body);
      if (tags.isNotEmpty) {
        final updated = note.copyWith(tags: tags);
        await updateNote(updated);
        if (kDebugMode) {
          debugPrint('✅ Background auto-tag successful for $noteId');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ autoTagNoteBackground failed: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  AI: Chat With Notes
  // ═════════════════════════════════════════════════════════════

  Future<String> chatWithNotes(String question) async {
    if (question.trim().isEmpty) return 'Please ask a question.';

    try {
      return await _ai.chatWithNotes(question, _notesList);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ chatWithNotes failed: $e');
      return 'Chat failed: $e';
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  AI: Check Calculation
  // ═════════════════════════════════════════════════════════════

  Future<String?> checkCalculation(String text) async {
    if (text.trim().isEmpty) return null;

    try {
      final result = await _ai.detectAndCalculate(text);
      if (result.trim().toUpperCase() == 'NONE') return null;
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ checkCalculation failed: $e');
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════
  //  Sync State
  // ═════════════════════════════════════════════════════════════

  void setSyncing(bool value) {
    if (_isSyncing != value) {
      _isSyncing = value;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _refreshFromHive();
    await _loadFolders();
  }

  // ═════════════════════════════════════════════════════════════
  //  Cleanup
  // ═════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _commitPendingDelete();
    _sync.removeListener(_onSyncChanged);
    _firestoreSub?.cancel();
    super.dispose();
  }
}
