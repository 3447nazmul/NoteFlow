import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/notes/models/folder_model.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Folder Service (Local Storage)
///
/// Hive-backed CRUD for user-created folders.
/// Uses a dedicated typed box: 'folders_box'.
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Service class for local Hive-backed CRUD operations on user folders.
class FolderService {
  static const String _boxName = 'folders_box';
  Box<Folder>? _box;

  // ─── Init ───

  // AI NOTE: Initializes and opens the Hive box for folders.
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<Folder>(_boxName);
    if (kDebugMode) {
      debugPrint('📂 Hive folders box opened (${_box!.length} folders)');
    }
  }

  // AI NOTE: Helper to ensure the Hive box for folders is open and return it.
  Future<Box<Folder>> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Folder>(_boxName);
    return _box!;
  }

  // ─── Create ───

  // AI NOTE: Creates a new folder in local storage with the given name and appends it to the sort order.
  Future<Folder> createFolder(String name, {String userId = ''}) async {
    final box = await _openBox();
    final allFolders = box.values.toList();
    final maxOrder = allFolders.isEmpty
        ? 0
        : allFolders.map((f) => f.sortOrder).reduce((a, b) => a > b ? a : b);

    final folder = Folder(name: name, userId: userId, sortOrder: maxOrder + 1);
    await box.put(folder.id, folder);
    return folder;
  }

  // ─── Rename ───

  // AI NOTE: Updates the name of an existing folder in local storage.
  Future<void> renameFolder(String folderId, String newName) async {
    final box = await _openBox();
    final folder = box.get(folderId);
    if (folder != null) {
      await box.put(folderId, folder.copyWith(name: newName));
    }
  }

  // ─── Delete ───

  // AI NOTE: Deletes a folder from local storage by its ID.
  Future<void> deleteFolder(String folderId) async {
    final box = await _openBox();
    await box.delete(folderId);
  }

  // ─── Read All ───

  // AI NOTE: Retrieves all locally stored folders, sorted by their order.
  Future<List<Folder>> getAllFolders() async {
    final box = await _openBox();
    final folders = box.values.toList();
    folders.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return folders;
  }

  // ─── Read One ───

  // AI NOTE: Retrieves a single folder by its ID from local storage.
  Future<Folder?> getFolderById(String folderId) async {
    final box = await _openBox();
    return box.get(folderId);
  }
}
