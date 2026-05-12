import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../../../shared/constants/app_colors.dart';
import '../../../shared/constants/app_strings.dart';
import '../../../services/ai_service.dart';
import '../../../services/api_key_service.dart';
import '../../../services/import_service.dart';
import '../../../services/sync_service.dart';
import '../../../services/app_config_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/notes_controller.dart';
import '../models/folder_model.dart';
import '../widgets/note_card.dart';
import '../../../shared/widgets/banner_ad_widget.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Notes List Screen
///
/// Primary screen showing all user notes in a responsive grid.
///
///  • App bar  →  app name + sort button + user avatar
///  • Search bar  →  real-time filter by title / body / tags
///  • Active tag bar  →  shows when filtering by a specific tag
///  • Grid  →  2 cols mobile · 3 cols tablet · 4 cols desktop
///  • FAB  →  + button to create a new note
///  • Empty state  →  illustration + call-to-action
///  • Pull to refresh  →  re-load from local storage
///  • Sync indicator  →  cloud_off icon on unsynced cards
/// ──────────────────────────────────────────────────────────────

// AI NOTE: The primary screen widget for displaying the list of notes.
class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

// AI NOTE: State class for NotesListScreen, managing the search controller, scaffold key, and rendering the UI grid.
class _NotesListScreenState extends State<NotesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // AI NOTE: Cleans up the search controller when the widget is disposed.
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // AI NOTE: Builds the main UI structure for the notes list screen.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const _FolderDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // ─────── Top bar + Search ───────
            _TopBar(
              searchController: _searchController,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),

            // ─────── Offline banner ───────
            const _OfflineBanner(),

            // ─────── API key prompt banner ───────
            const _ApiKeyBanner(),

            // ─────── Active tag filter bar ───────
            const _ActiveTagBar(),

            // ─────── Notes grid ───────
            // ─────── Trash bar (when in trash view) ───────
            const _TrashBar(),

            Expanded(
              child: Consumer<NotesController>(
                builder: (context, controller, _) {
                  if (controller.isLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.primary,
                      ),
                    );
                  }

                  final notes = controller.filteredNotes;
                  final query = controller.searchQuery;
                  final isSearching = query.isNotEmpty;
                  final totalCount = controller.notesList
                      .where((n) => !n.isDeleted)
                      .length;
                  final isTrash = controller.isTrashView;
                  final pinnedCount = controller.pinnedCount;

                  if (notes.isEmpty) {
                    return _EmptyState(
                      isSearching:
                          isSearching || controller.activeTag.isNotEmpty,
                      isTrash: isTrash,
                    );
                  }

                  return RefreshIndicator(
                    color: cs.primary,
                    displacement: 24,
                    onRefresh: () => controller.loadNotes(),
                    child: Column(
                      children: [
                        _SearchResultsBar(
                          isSearching: isSearching,
                          resultCount: notes.length,
                          totalCount: totalCount,
                          query: query,
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = _gridColumns(
                                constraints.maxWidth,
                              );
                              return CustomScrollView(
                                slivers: [
                                  // Pinned section header
                                  if (pinnedCount > 0 && !isTrash)
                                    SliverPadding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        8,
                                        20,
                                        4,
                                      ),
                                      sliver: SliverToBoxAdapter(
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.push_pin_rounded,
                                              size: 14,
                                              color: cs.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Pinned',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: cs.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  // Pinned notes grid
                                  if (pinnedCount > 0 && !isTrash)
                                    SliverPadding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      sliver: SliverGrid(
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: columns,
                                              mainAxisSpacing: 8,
                                              crossAxisSpacing: 8,
                                              childAspectRatio: _aspectRatio(
                                                columns,
                                              ),
                                            ),
                                        delegate: SliverChildBuilderDelegate(
                                          (ctx, i) => NoteCard(
                                            note: notes[i],
                                            searchQuery: query,
                                          ),
                                          childCount: pinnedCount,
                                        ),
                                      ),
                                    ),
                                  // "Other notes" header
                                  if (pinnedCount > 0 &&
                                      pinnedCount < notes.length &&
                                      !isTrash)
                                    SliverPadding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        12,
                                        20,
                                        4,
                                      ),
                                      sliver: SliverToBoxAdapter(
                                        child: Text(
                                          'Other Notes',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Unpinned / all notes grid
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      100,
                                    ),
                                    sliver: SliverGrid(
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: columns,
                                            mainAxisSpacing: 8,
                                            crossAxisSpacing: 8,
                                            childAspectRatio: _aspectRatio(
                                              columns,
                                            ),
                                          ),
                                      delegate: SliverChildBuilderDelegate(
                                        (ctx, i) {
                                          final idx = isTrash
                                              ? i
                                              : pinnedCount + i;
                                          return NoteCard(
                                            note: notes[idx],
                                            searchQuery: query,
                                            isTrashMode: isTrash,
                                          );
                                        },
                                        childCount: isTrash
                                            ? notes.length
                                            : notes.length - pinnedCount,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // ─────── FAB (hidden in trash view) ───────
      floatingActionButton: context.watch<NotesController>().isTrashView
          ? null
          : FloatingActionButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final controller = context.read<NotesController>();
                final note = await controller.createNote();
                if (context.mounted) {
                  Navigator.pushNamed(context, '/editor', arguments: note.id);
                }
              },
              tooltip: AppStrings.newNote,
              child: const Icon(Icons.add_rounded, size: 28),
            ),
      bottomNavigationBar: const BannerAdWidget(),
    );
  }

  /// Responsive column count based on screen width.
  // AI NOTE: Calculates the number of columns for the notes grid based on available screen width.
  int _gridColumns(double width) {
    if (width >= 1200) return 4; // desktop
    if (width >= 720) return 3; // tablet
    return 2; // mobile
  }

  /// Taller cards on wider screens (more room per card).
  // AI NOTE: Calculates the aspect ratio for note cards based on the number of columns.
  double _aspectRatio(int columns) {
    switch (columns) {
      case 4:
        return 1.0;
      case 3:
        return 0.88;
      default:
        return 0.85;
    }
  }
}

/// ──────────────────────────────────────────────────────────────
/// Top Bar  (app name · sort · avatar · search)
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Widget for the top app bar, including the menu button, title, search field, and action buttons.
class _TopBar extends StatelessWidget {
  final TextEditingController searchController;
  final VoidCallback? onMenuTap;

  const _TopBar({required this.searchController, this.onMenuTap});

  // AI NOTE: Builds the top bar UI.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = context.watch<NotesController>();
    final isTrash = controller.isTrashView;
    final activeFolder = controller.activeFolder;
    final folderName = activeFolder != null
        ? controller.foldersList
              .where((f) => f.id == activeFolder)
              .map((f) => f.name)
              .firstOrNull
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              // Menu button
              IconButton(
                icon: Icon(Icons.menu_rounded, color: cs.onSurfaceVariant),
                tooltip: 'Folders',
                onPressed: onMenuTap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              // Title
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isTrash ? 'Trash' : folderName ?? AppStrings.appName,
                          style: GoogleFonts.poppins(
                            fontSize: isTrash || folderName != null ? 22 : 28,
                            fontWeight: FontWeight.w800,
                            color: isTrash ? cs.error : cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                    if (!isTrash && folderName == null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          context.watch<AppConfigService>().betaBadgeText.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isTrash && activeFolder != null)
                IconButton(
                  icon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: cs.primary,
                  ),
                  tooltip: 'Chat with Folder',
                  onPressed: () => _showFolderChatDialog(
                    context,
                    activeFolder,
                    folderName ?? 'Folder',
                  ),
                ),
              if (!isTrash)
                IconButton(
                  icon: Icon(
                    Icons.file_upload_outlined,
                    color: cs.onSurfaceVariant,
                  ),
                  tooltip: 'Import File',
                  onPressed: () => _handleImportFile(context),
                ),
              if (!isTrash) const _SortButton(),
              if (!isTrash)
                IconButton(
                  icon: Icon(Icons.settings_outlined, color: cs.onSurfaceVariant),
                  tooltip: 'Settings',
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                ),
              const SizedBox(width: 4),
              _UserAvatar(),
            ],
          ),
          const SizedBox(height: 16),
          if (!isTrash) _SearchField(controller: searchController),
          if (!isTrash) const SizedBox(height: 12),
        ],
      ),
    );
  }

  // AI NOTE: Shows a dialog to chat with AI about the contents of a specific folder.
  Future<void> _showFolderChatDialog(
    BuildContext context,
    String folderId,
    String folderName,
  ) async {
    final controller = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    final question = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Ask AI about $folderName',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.poppins(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'e.g. Summarize the notes in this folder',
            hintStyle: GoogleFonts.poppins(
              fontSize: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Ask'),
          ),
        ],
      ),
    );

    if (question == null || question.trim().isEmpty) return;

    if (!context.mounted) return;

    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          Center(child: CircularProgressIndicator(color: cs.primary)),
    );

    try {
      final appConfigService = context.read<AppConfigService>();
      final aiService = AiService(ApiKeyService(), appConfigService);
      final notesController = context.read<NotesController>();
      final notesInFolder = notesController.notesList
          .where((n) => n.folderId == folderId && !n.isDeleted)
          .toList();

      if (notesInFolder.isEmpty) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No notes in this folder.')),
          );
        }
        return;
      }

      final response = await aiService.chatWithNotes(question, notesInFolder);

      if (!context.mounted) return;
      Navigator.pop(context); // close loading

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'AI Response',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Text(response, style: GoogleFonts.poppins(fontSize: 15)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI request failed: $e')));
    }
  }

  // AI NOTE: Handles importing a file, extracting its text (or audio transcription), and creating a new note.
  Future<void> _handleImportFile(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'txt',
          'html',
          'pdf',
          'pptx',
          'mp3',
          'wav',
          'm4a',
          'aac',
          'ogg',
        ],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final extension = file.path.split('.').last.toLowerCase();

      if (!context.mounted) return;

      // Show Loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            Center(child: CircularProgressIndicator(color: cs.primary)),
      );

      String? text;
      final audioExtensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg'];

      if (audioExtensions.contains(extension)) {
        final bytes = await file.readAsBytes();
        String mimeType = 'audio/$extension';
        if (extension == 'm4a') mimeType = 'audio/mp4';

        if (!context.mounted) return;
        final appConfigService = context.read<AppConfigService>();
        final aiService = AiService(ApiKeyService(), appConfigService);
        text = await aiService.transcribeAudio(bytes, mimeType);
      } else {
        text = await ImportService.extractTextFromFile(file);
      }

      if (!context.mounted) return;
      Navigator.pop(context); // close loading

      if (text == null || text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not extract text from the selected file.'),
          ),
        );
        return;
      }

      // Create a new note with the text
      final controller = context.read<NotesController>();
      final newNote = await controller.createNote();
      final updatedNote = newNote.copyWith(title: fileName, body: text);
      await controller.updateNote(updatedNote);

      if (context.mounted) {
        Navigator.pushNamed(context, '/editor', arguments: updatedNote.id);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }
}

/// ──────────────────────────────────────────────────────────────
/// Sort Button — popup menu for sort modes
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Widget for the sort button, allowing the user to select the sorting mode for notes.
class _SortButton extends StatelessWidget {
  const _SortButton();

  // AI NOTE: Builds the sort button UI with a popup menu.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentSort = context.select<NotesController, SortMode>(
      (c) => c.sortMode,
    );

    return PopupMenuButton<SortMode>(
      icon: Icon(Icons.sort_rounded, color: cs.onSurfaceVariant),
      tooltip: 'Sort notes',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (mode) {
        HapticFeedback.selectionClick();
        context.read<NotesController>().setSortMode(mode);
      },
      itemBuilder: (_) => SortMode.values.map((mode) {
        final isActive = mode == currentSort;

        return PopupMenuItem<SortMode>(
          value: mode,
          child: Row(
            children: [
              Icon(
                _sortIcon(mode),
                size: 18,
                color: isActive ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mode.label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? cs.primary : cs.onSurface,
                  ),
                ),
              ),
              if (isActive)
                Icon(Icons.check_rounded, size: 18, color: cs.primary),
            ],
          ),
        );
      }).toList(),
    );
  }

  // AI NOTE: Returns the appropriate icon for the given sort mode.
  IconData _sortIcon(SortMode mode) {
    switch (mode) {
      case SortMode.dateModified:
        return Icons.update_rounded;
      case SortMode.dateCreated:
        return Icons.calendar_today_rounded;
      case SortMode.alphabetical:
        return Icons.sort_by_alpha_rounded;
    }
  }
}

/// ──────────────────────────────────────────────────────────────
/// Active Tag Bar — shows when filtering by a specific tag.
/// Provides a clear button to remove the filter.
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Widget that displays the currently active tag filter, if any, and allows clearing it.
class _ActiveTagBar extends StatelessWidget {
  const _ActiveTagBar();

  // AI NOTE: Builds the active tag bar UI.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeTag = context.select<NotesController, String>(
      (c) => c.activeTag,
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: activeTag.isEmpty
          ? const SizedBox.shrink()
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.label_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                        children: [
                          const TextSpan(text: 'Filtered by '),
                          TextSpan(
                            text: '#$activeTag',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.read<NotesController>().clearTagFilter();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// API Key Banner — elegant prompt to add API key for AI features
/// ──────────────────────────────────────────────────────────────

class _ApiKeyBanner extends StatefulWidget {
  const _ApiKeyBanner();

  @override
  State<_ApiKeyBanner> createState() => _ApiKeyBannerState();
}

class _ApiKeyBannerState extends State<_ApiKeyBanner> {
  bool _hasApiKey = true; // assume true until checked

  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }

  Future<void> _checkApiKey() async {
    final config = context.read<AppConfigService>();
    if (config.useGlobalApiKeys) {
      if (mounted) setState(() => _hasApiKey = true);
      return;
    }
    final key = await ApiKeyService().getActiveKey();
    if (mounted) {
      setState(() {
        _hasApiKey = key != null && key.trim().isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _hasApiKey
          ? const SizedBox.shrink()
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withValues(alpha: 0.08),
                    cs.tertiary.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Add API to smart AI note',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 30,
                    child: FilledButton.tonal(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/settings'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// User Avatar — shows profile pic or initials; opens account
/// bottom sheet on tap.
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Widget that displays the user's avatar or initials, and opens the account sheet when tapped.
class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthController>();
    final user = auth.getCurrentUser();

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showAccountSheet(context);
      },
      child: CircleAvatar(
        radius: 20,
        backgroundColor: cs.primaryContainer,
        backgroundImage: user?.photoURL != null
            ? NetworkImage(user!.photoURL!)
            : null,
        child: user?.photoURL == null
            ? Text(
                _initials(user?.displayName),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onPrimaryContainer,
                ),
              )
            : null,
      ),
    );
  }

  // AI NOTE: Generates the initials from the user's display name.
  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  // AI NOTE: Shows the account bottom sheet with user details.
  void _showAccountSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.read<AuthController>();
    final user = auth.getCurrentUser();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Avatar
                CircleAvatar(
                  radius: 36,
                  backgroundColor: cs.primaryContainer,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 36,
                          color: cs.onPrimaryContainer,
                        )
                      : null,
                ),
                const SizedBox(height: 14),

                // Name
                Text(
                  user?.displayName ?? 'Guest',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),

                // Email
                if (user?.email != null)
                  Text(
                    user!.email!,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),

                const SizedBox(height: 20),
                Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),

                // Sign out
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: cs.error),
                  title: Text(
                    AppStrings.signOutLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: cs.error,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    await auth.signOut();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Search Field — filters notes in real time by title, body, tags.
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Widget for the search field, allowing the user to filter notes in real time.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  // AI NOTE: Builds the search field UI.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      onChanged: (query) {
        context.read<NotesController>().setSearchQuery(query);
      },
      style: GoogleFonts.poppins(fontSize: 15, color: cs.onSurface),
      decoration: InputDecoration(
        hintText: AppStrings.searchHint,
        hintStyle: GoogleFonts.poppins(
          fontSize: 15,
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 22,
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                controller.clear();
                context.read<NotesController>().setSearchQuery('');
              },
            );
          },
        ),
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Search Results Bar — shows result count during active search.
///
/// Slides in smoothly when a search query is active and displays
/// "X of Y notes" with a highlighted query snippet.
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Widget that shows the result count during an active search.
class _SearchResultsBar extends StatelessWidget {
  final bool isSearching;
  final int resultCount;
  final int totalCount;
  final String query;

  const _SearchResultsBar({
    required this.isSearching,
    required this.resultCount,
    required this.totalCount,
    required this.query,
  });

  // AI NOTE: Builds the search results bar UI.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: isSearching
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_list_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 10),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: '$resultCount',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                        TextSpan(text: ' of $totalCount notes match '),
                        TextSpan(
                          text: '"$query"',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Empty State — shown when no notes exist (or search yields 0).
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Widget shown when no notes exist or search yields no results.
class _EmptyState extends StatelessWidget {
  final bool isSearching;
  final bool isTrash;

  const _EmptyState({this.isSearching = false, this.isTrash = false});

  // AI NOTE: Builds the empty state UI.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final icon = isTrash
        ? Icons.delete_outline_rounded
        : isSearching
        ? Icons.search_off_rounded
        : Icons.note_add_outlined;
    final title = isTrash
        ? 'Trash is empty'
        : isSearching
        ? 'No notes found'
        : 'No notes yet';
    final subtitle = isTrash
        ? 'Deleted notes will appear here'
        : isSearching
        ? 'Try a different search term or clear the filter'
        : 'Tap the + button to create\nyour first note.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: (isTrash ? cs.error : cs.primaryContainer).withValues(
                  alpha: 0.25,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 52,
                  color: (isTrash ? cs.error : AppColors.brandIndigo)
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                height: 1.6,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Offline Banner — shown at top of list when device is offline.
/// Also shows a syncing indicator when reconnecting.
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Widget shown at the top of the list when the device is offline or syncing.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  // AI NOTE: Builds the offline banner UI.
  @override
  Widget build(BuildContext context) {
    return Consumer<SyncService>(
      builder: (context, sync, _) {
        // Don't show anything when online and not syncing
        if (sync.isOnline && !sync.isSyncing) {
          return const SizedBox.shrink();
        }

        final cs = Theme.of(context).colorScheme;

        // Syncing banner
        if (sync.isSyncing) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Syncing notes…',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          );
        }

        // Offline banner
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 18,
                color: cs.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You\'re offline. Changes will sync when you reconnect.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Folder Drawer — navigation for folders & trash
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Widget for the drawer providing navigation for folders and trash.
class _FolderDrawer extends StatelessWidget {
  const _FolderDrawer();

  // AI NOTE: Builds the folder drawer UI.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = context.watch<NotesController>();
    final folders = controller.foldersList;
    final active = controller.activeFolder;
    final isTrash = controller.isTrashView;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Folders',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ),

            // All Notes
            _DrawerItem(
              icon: Icons.notes_rounded,
              label: 'All Notes',
              isActive: active == null && !isTrash,
              onTap: () {
                controller.showAllNotes();
                Navigator.pop(context);
              },
            ),

            if (folders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  'MY FOLDERS',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),

            // Folders list
            ...folders.map(
              (folder) => _DrawerItem(
                icon: active == folder.id
                    ? Icons.folder_rounded
                    : Icons.folder_outlined,
                label: folder.name,
                isActive: active == folder.id,
                onTap: () {
                  controller.setActiveFolder(folder.id);
                  Navigator.pop(context);
                },
                onLongPress: () => _showFolderActions(context, folder),
              ),
            ),

            const Spacer(),

            // New Folder button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListTile(
                leading: Icon(
                  Icons.create_new_folder_outlined,
                  size: 22,
                  color: cs.primary,
                ),
                title: Text(
                  'New Folder',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => _createFolder(context),
              ),
            ),

            Divider(
              indent: 20,
              endIndent: 20,
              color: cs.outlineVariant.withValues(alpha: 0.3),
            ),

            // Trash
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: _DrawerItem(
                icon: Icons.delete_outline_rounded,
                label: 'Trash',
                isActive: isTrash,
                color: cs.error,
                onTap: () {
                  controller.showTrash();
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // AI NOTE: Shows a dialog to create a new folder.
  void _createFolder(BuildContext context) {
    final tec = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'New Folder',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: tec,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: GoogleFonts.poppins(fontSize: 14),
          ),
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = tec.text.trim();
              if (name.isNotEmpty) {
                context.read<NotesController>().createFolder(name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // AI NOTE: Shows a bottom sheet with actions to rename or delete a folder.
  void _showFolderActions(BuildContext context, Folder folder) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: cs.onSurface),
              title: Text('Rename', style: GoogleFonts.poppins(fontSize: 15)),
              onTap: () {
                Navigator.pop(context);
                _renameFolder(context, folder);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: cs.error),
              title: Text(
                'Delete Folder',
                style: GoogleFonts.poppins(fontSize: 15, color: cs.error),
              ),
              onTap: () {
                Navigator.pop(context);
                context.read<NotesController>().deleteFolder(folder.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // AI NOTE: Shows a dialog to rename an existing folder.
  void _renameFolder(BuildContext context, Folder folder) {
    final tec = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Rename Folder',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: tec,
          autofocus: true,
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = tec.text.trim();
              if (name.isNotEmpty) {
                context.read<NotesController>().renameFolder(folder.id, name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}

/// Drawer item tile
// AI NOTE: Drawer item tile widget for navigation.
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? color;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.onLongPress,
    this.color,
  });

  // AI NOTE: Builds the drawer item tile UI.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? (isActive ? cs.primary : cs.onSurface);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListTile(
        leading: Icon(icon, size: 22, color: c),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: c,
          ),
        ),
        selected: isActive,
        selectedTileColor: cs.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: onLongPress,
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Trash Bar — shown when viewing trash
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Widget shown when viewing trash, allowing the user to empty the trash.
class _TrashBar extends StatelessWidget {
  const _TrashBar();

  // AI NOTE: Builds the trash bar UI.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTrash = context.select<NotesController, bool>((c) => c.isTrashView);

    if (!isTrash) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: cs.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Notes are permanently deleted after 30 days',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(
                    'Empty Trash',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  content: Text(
                    'Permanently delete all trashed notes?',
                    style: GoogleFonts.poppins(height: 1.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        'Delete All',
                        style: TextStyle(color: cs.error),
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                context.read<NotesController>().emptyTrash();
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: cs.error,
              textStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Empty Trash'),
          ),
        ],
      ),
    );
  }
}
