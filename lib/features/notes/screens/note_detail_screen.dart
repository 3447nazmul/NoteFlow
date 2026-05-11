import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../shared/constants/app_strings.dart';
import '../../../shared/utils/date_formatter.dart';
import '../controllers/notes_controller.dart';
import '../models/note_model.dart';
import '../widgets/tag_chip.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Note Detail Screen
///
/// Full read-only view of a note with:
///  • Title and full body text
///  • Edit button → opens NoteEditorScreen
///  • AI summary card (if summary exists)
///  • Tag chips in a wrap row
///  • Created / updated timestamps
///  • Share button → copies to clipboard
///  • Delete with confirmation
/// ──────────────────────────────────────────────────────────────

// AI NOTE: UI for the read-only note detail view, featuring metadata, tags, AI summary, and action buttons.
class NoteDetailScreen extends StatelessWidget {
  final String noteId;
  const NoteDetailScreen({super.key, required this.noteId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = context.watch<NotesController>();
    final note = controller.getNoteById(noteId);

    if (note == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.note_outlined,
                size: 56,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Note not found',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'This note may have been deleted.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── App Bar ───
          _DetailAppBar(note: note, noteId: noteId),

          // ─── Content ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Title ──
                  Text(
                    note.displayTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Meta row: updated time + sync status ──
                  _MetaRow(note: note),

                  // ── Tags ──
                  if (note.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _TagsSection(tags: note.tags),
                  ],

                  // ── AI Summary Card ──
                  if (note.summary.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _AiSummaryCard(summary: note.summary),
                  ],

                  const SizedBox(height: 24),

                  // ── Divider ──
                  Divider(
                    color: cs.outlineVariant.withValues(alpha: 0.25),
                    height: 1,
                  ),

                  const SizedBox(height: 24),

                  // ── Body ──
                  note.body.isEmpty
                      ? _EmptyBody()
                      : SelectableText(
                          note.body,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 1.75,
                            color: cs.onSurface,
                          ),
                        ),

                  const SizedBox(height: 40),

                  // ── Timestamps ──
                  _TimestampsSection(note: note),

                  const SizedBox(height: 32),

                  // ── Action Buttons (Share + Delete) ──
                  _ActionButtonsRow(note: note),

                  // Bottom safe area padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Sliver App Bar — Edit button in the top bar
/// ──────────────────────────────────────────────────────────────

class _DetailAppBar extends StatelessWidget {
  final Note note;
  final String noteId;

  const _DetailAppBar({required this.note, required this.noteId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      expandedHeight: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // Edit button
        _AppBarAction(
          icon: Icons.edit_outlined,
          tooltip: 'Edit Note',
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pushNamed(context, '/editor', arguments: noteId);
          },
        ),
        // More menu
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
          tooltip: 'More options',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (_) => [
            _popupItem('share', Icons.copy_outlined, 'Copy to Clipboard', cs),
            _popupItem(
              'delete',
              Icons.delete_outline_rounded,
              AppStrings.deleteNote,
              cs,
              isDestructive: true,
            ),
          ],
          onSelected: (value) {
            HapticFeedback.selectionClick();
            if (value == 'share') {
              _copyToClipboard(context, note);
            } else if (value == 'delete') {
              _deleteWithUndo(context, note);
            }
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  PopupMenuItem<String> _popupItem(
    String value,
    IconData icon,
    String label,
    ColorScheme cs, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? cs.error : cs.onSurface;

    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, Note note) {
    final buffer = StringBuffer();
    buffer.writeln(note.displayTitle);
    buffer.writeln();
    if (note.body.isNotEmpty) buffer.writeln(note.body);
    if (note.tags.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Tags: ${note.tags.join(', ')}');
    }
    if (note.summary.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Summary: ${note.summary}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));

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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteWithUndo(BuildContext context, Note note) {
    HapticFeedback.mediumImpact();
    final controller = context.read<NotesController>();
    final deletedNote = controller.deleteNote(note.id);

    Navigator.pop(context); // pop detail screen

    if (deletedNote == null) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '"${deletedNote.displayTitle}" deleted',
                style: GoogleFonts.poppins(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            HapticFeedback.mediumImpact();
            controller.undoDelete();
          },
        ),
      ),
    );
  }
}

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return IconButton(
      icon: Icon(icon, color: cs.onSurfaceVariant),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Meta Row — Updated time + sync indicator
/// ──────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final Note note;
  const _MetaRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          Icons.schedule_rounded,
          size: 14,
          color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        ),
        const SizedBox(width: 5),
        Text(
          'Edited ${DateFormatter.relative(note.updatedAt)}',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 12),

        // Sync status pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: note.isSynced
                ? cs.primary.withValues(alpha: 0.08)
                : cs.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                note.isSynced
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                size: 12,
                color: note.isSynced ? cs.primary : cs.error,
              ),
              const SizedBox(width: 4),
              Text(
                note.isSynced ? 'Synced' : 'Offline',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: note.isSynced ? cs.primary : cs.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Tags Section — Wrap of TagChip widgets
/// ──────────────────────────────────────────────────────────────

class _TagsSection extends StatelessWidget {
  final List<String> tags;
  const _TagsSection({required this.tags});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Row(
          children: [
            Icon(
              Icons.label_outline_rounded,
              size: 15,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Text(
              'Tags',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: tags.map((tag) => TagChip(label: tag)).toList(),
        ),
      ],
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// AI Summary Card — Glassmorphic-style card with sparkle icon
/// ──────────────────────────────────────────────────────────────

class _AiSummaryCard extends StatelessWidget {
  final String summary;
  const _AiSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withValues(alpha: 0.35),
            cs.tertiaryContainer.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.12), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'AI Summary',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Summary text
          Text(
            summary,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.6,
              color: cs.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Empty Body Placeholder
/// ──────────────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.notes_rounded,
            size: 40,
            color: cs.onSurfaceVariant.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            'No content yet',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the edit button to start writing.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Timestamps Section — Created and Updated dates
/// ──────────────────────────────────────────────────────────────

class _TimestampsSection extends StatelessWidget {
  final Note note;
  const _TimestampsSection({required this.note});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _TimestampRow(
            icon: Icons.add_circle_outline_rounded,
            label: 'Created',
            date: DateFormatter.full(note.createdAt),
          ),
          const SizedBox(height: 10),
          _TimestampRow(
            icon: Icons.update_rounded,
            label: 'Last edited',
            date: DateFormatter.full(note.updatedAt),
          ),
        ],
      ),
    );
  }
}

class _TimestampRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String date;

  const _TimestampRow({
    required this.icon,
    required this.label,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: cs.onSurfaceVariant.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        Text(
          date,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Action Buttons — Share + Edit (full-width)
/// ──────────────────────────────────────────────────────────────

class _ActionButtonsRow extends StatelessWidget {
  final Note note;
  const _ActionButtonsRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Share / Copy button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              _copyToClipboard(context);
            },
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: Text(
              'Copy Text',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Edit button
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pushNamed(context, '/editor', arguments: note.id);
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(
              'Edit Note',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln(note.displayTitle);
    buffer.writeln();
    if (note.body.isNotEmpty) buffer.writeln(note.body);
    if (note.tags.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Tags: ${note.tags.join(', ')}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString().trim()));

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
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
