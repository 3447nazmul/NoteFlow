import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../shared/utils/date_formatter.dart';
import '../controllers/notes_controller.dart';
import '../models/note_model.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Note Card Widget
///
/// Reusable card for the notes grid.  Follows Lumina Focus tokens:
///  • 12px radius  •  20px inner padding  •  tonal surface bg
///  • Poppins typography  •  outline-style icons
///
/// Tap  → opens NoteDetailScreen (with haptic feedback)
/// Long-press → context menu (Edit · Pin/Unpin · Move to Folder ·
///              Move to Trash · Share)
///
/// Phase 17 additions:
///  • Pin icon indicator on pinned cards
///  • "Pin/Unpin" in context menu
///  • "Move to Folder" in context menu
///  • "Move to Trash" replaces hard delete
///  • Trash mode: "Restore" and "Delete Permanently"
/// ──────────────────────────────────────────────────────────────

// AI NOTE: A reusable card widget displaying note preview, tags, and sync status in grid/list views.
class NoteCard extends StatelessWidget {
  final Note note;
  final String searchQuery;
  final ValueChanged<String>? onTagTap;
  final bool isTrashMode;

  const NoteCard({
    super.key,
    required this.note,
    this.searchQuery = '',
    this.onTagTap,
    this.isTrashMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = context.read<NotesController>();
    final activeTag = context.select<NotesController, String>(
      (c) => c.activeTag,
    );

    String previewText = note.body;
    if (previewText.startsWith('[{"insert"')) {
      try {
        final json = jsonDecode(previewText);
        previewText = quill.Document.fromJson(json).toPlainText().trim();
      } catch (e) {
        // Fallback if parsing fails
      }
    }

    return Card(
      child: InkWell(
        onTap: () {
          if (isTrashMode) return; // No navigation from trash
          HapticFeedback.selectionClick();
          Navigator.pushNamed(context, '/detail', arguments: note.id);
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          if (isTrashMode) {
            _showTrashContextMenu(context);
          } else {
            _showContextMenu(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Title + Pin/Sync indicators ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pin indicator
                  if (note.isPinned && !isTrashMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 6, top: 2),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: cs.primary,
                      ),
                    ),
                  Expanded(
                    child: HighlightedText(
                      text: note.displayTitle,
                      query: searchQuery,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        height: 1.3,
                      ),
                      highlightColor: cs.primary.withValues(alpha: 0.15),
                      highlightTextColor: cs.primary,
                      maxLines: 2,
                    ),
                  ),
                  // Sync indicator — cloud icon when NOT synced
                  if (!note.isSynced && !isTrashMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Tooltip(
                        message: 'Not synced to cloud',
                        child: Icon(
                          Icons.cloud_off_outlined,
                          size: 15,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // ─── Body preview (first 80 chars) ───
              if (previewText.isNotEmpty)
                HighlightedText(
                  text: previewText.length > 80
                      ? '${previewText.substring(0, 80)}…'
                      : previewText,
                  query: searchQuery,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.5,
                    color: cs.onSurfaceVariant,
                  ),
                  highlightColor: cs.primary.withValues(alpha: 0.12),
                  highlightTextColor: cs.primary,
                  maxLines: 3,
                ),

              // ─── Checklist preview ───
              if (note.checklist.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ChecklistPreview(checklist: note.checklist),
              ],

              // ─── Tags as tappable filter chips ───
              if (note.tags.isNotEmpty && !isTrashMode) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: note.tags.take(3).map((tag) {
                    final isMatch =
                        searchQuery.isNotEmpty &&
                        tag.toLowerCase().contains(searchQuery.toLowerCase());
                    final isActive =
                        activeTag.isNotEmpty &&
                        tag.toLowerCase() == activeTag.toLowerCase();

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (onTagTap != null) {
                          onTagTap!(tag);
                        } else {
                          controller.setActiveTag(tag);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? cs.primary.withValues(alpha: 0.25)
                              : isMatch
                              ? cs.primary.withValues(alpha: 0.22)
                              : cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(9999),
                          border: (isMatch || isActive)
                              ? Border.all(
                                  color: cs.primary.withValues(alpha: 0.4),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: (isMatch || isActive)
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // ─── Time label ───
              const SizedBox(height: 12),
              Text(
                isTrashMode && note.daysUntilPurge != null
                    ? '${note.daysUntilPurge} days until permanent deletion'
                    : DateFormatter.relative(note.updatedAt),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: isTrashMode
                      ? cs.error.withValues(alpha: 0.7)
                      : cs.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Normal context menu ───

  void _showContextMenu(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = context.read<NotesController>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),

              // ── Edit ──
              ListTile(
                leading: Icon(Icons.edit_outlined, color: cs.onSurface),
                title: Text(
                  'Edit',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/editor', arguments: note.id);
                },
              ),

              // ── Pin / Unpin ──
              ListTile(
                leading: Icon(
                  note.isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  color: cs.onSurface,
                ),
                title: Text(
                  note.isPinned ? 'Unpin' : 'Pin to Top',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  controller.togglePin(note.id);
                },
              ),

              // ── Move to Folder ──
              ListTile(
                leading: Icon(Icons.folder_outlined, color: cs.onSurface),
                title: Text(
                  'Move to Folder',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  _showFolderPicker(context);
                },
              ),

              // ── Share ──
              ListTile(
                leading: Icon(Icons.share_outlined, color: cs.onSurface),
                title: Text(
                  'Share',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  _shareNote(context);
                },
              ),

              // ── Move to Trash ──
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: cs.error),
                title: Text(
                  'Move to Trash',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.error,
                  ),
                ),
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  controller.moveToTrash(note.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '"${note.displayTitle}" moved to trash',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ─── Trash context menu ───

  void _showTrashContextMenu(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = context.read<NotesController>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),

              // ── Restore ──
              ListTile(
                leading: Icon(Icons.restore_rounded, color: cs.primary),
                title: Text(
                  'Restore',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                  ),
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  controller.restoreFromTrash(note.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '"${note.displayTitle}" restored',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ),
                  );
                },
              ),

              // ── Delete Permanently ──
              ListTile(
                leading: Icon(Icons.delete_forever_rounded, color: cs.error),
                title: Text(
                  'Delete Permanently',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.error,
                  ),
                ),
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(
                        'Delete Permanently',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      content: Text(
                        'This note will be permanently deleted and cannot be recovered.',
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
                            'Delete',
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    controller.permanentlyDelete(note.id);
                  }
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ─── Folder picker ───

  void _showFolderPicker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = context.read<NotesController>();
    final folders = controller.foldersList;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Move to Folder',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              // Unfiled option
              ListTile(
                leading: Icon(Icons.notes_rounded, color: cs.onSurface),
                title: Text(
                  'All Notes (Unfiled)',
                  style: GoogleFonts.poppins(fontSize: 15),
                ),
                trailing: note.folderId == null
                    ? Icon(Icons.check_rounded, size: 20, color: cs.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  controller.moveNoteToFolder(note.id, null);
                },
              ),

              // Folders
              ...folders.map((folder) {
                final isActive = note.folderId == folder.id;
                return ListTile(
                  leading: Icon(
                    isActive ? Icons.folder_rounded : Icons.folder_outlined,
                    color: isActive ? cs.primary : cs.onSurface,
                  ),
                  title: Text(
                    folder.name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? cs.primary : cs.onSurface,
                    ),
                  ),
                  trailing: isActive
                      ? Icon(Icons.check_rounded, size: 20, color: cs.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    controller.moveNoteToFolder(note.id, folder.id);
                  },
                );
              }),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  /// Copy note content to clipboard (share).
  void _shareNote(BuildContext context) {
    String bodyText = note.body;
    if (bodyText.startsWith('[{"insert"')) {
      try {
        final json = jsonDecode(bodyText);
        bodyText = quill.Document.fromJson(json).toPlainText().trim();
      } catch (_) {
        // Fallback to raw body
      }
    }
    final text = '${note.displayTitle}\n\n$bodyText';
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              'Note copied to clipboard',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Checklist Preview — compact summary on card
/// ──────────────────────────────────────────────────────────────

// AI NOTE: A compact widget to preview the completion status of a note's checklist.
class _ChecklistPreview extends StatelessWidget {
  final List<Map<String, dynamic>> checklist;

  const _ChecklistPreview({required this.checklist});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completed = checklist.where((i) => i['checked'] == true).length;
    final total = checklist.length;

    return Row(
      children: [
        Icon(Icons.checklist_rounded, size: 14, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          '$completed/$total tasks',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: completed == total ? Colors.green.shade600 : cs.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: total > 0 ? completed / total : 0,
              minHeight: 3,
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                completed == total ? Colors.green : cs.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Highlighted Text Widget
/// ──────────────────────────────────────────────────────────────

// AI NOTE: A utility widget that highlights search query matches within the note text.
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final Color highlightColor;
  final Color highlightTextColor;
  final int maxLines;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    required this.highlightColor,
    required this.highlightTextColor,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = _buildSpans();
    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<TextSpan> _buildSpans() {
    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (start < text.length) {
      final matchIndex = lowerText.indexOf(lowerQuery, start);
      if (matchIndex == -1) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      if (matchIndex > start) {
        spans.add(
          TextSpan(text: text.substring(start, matchIndex), style: style),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(matchIndex, matchIndex + query.length),
          style: style.copyWith(
            fontWeight: FontWeight.w700,
            color: highlightTextColor,
            backgroundColor: highlightColor,
          ),
        ),
      );
      start = matchIndex + query.length;
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: style));
    }
    return spans;
  }
}
