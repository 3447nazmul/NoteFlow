import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — AI Action Bar
///
/// Horizontal bar that sits above the keyboard in the note editor.
/// Each button triggers an AI operation on the current note body,
/// shows a per-button loading spinner, and displays results in a
/// bottom sheet overlay — never navigates away from the note.
///
/// Buttons:
///   ✨ Summarise   🏷️ Auto-tag   💬 Ask AI   🔢 Calculate
///
/// The [onAction] callback receives the action name and a
/// [Function(String)] to deliver the result text back.
/// ──────────────────────────────────────────────────────────────

// AI NOTE: A widget that displays a row of AI-powered action buttons (Summarise, Auto-tag, etc.)
class AiActionBar extends StatefulWidget {
  /// Called when user taps an AI action.
  ///
  /// Parameters:
  ///  • action name  (e.g. "Summarise")
  ///  • a callback to return the result string
  final Future<String> Function(String action)? onAction;

  const AiActionBar({super.key, this.onAction});

  @override
  State<AiActionBar> createState() => _AiActionBarState();
}

class _AiActionBarState extends State<AiActionBar> {
  /// Tracks which button (by index) is currently loading.
  int _loadingIndex = -1;

  static const _actions = [
    _AiButton(
      icon: Icons.auto_awesome_rounded,
      label: 'Summarise',
      resultTitle: 'AI Summary',
    ),
    _AiButton(
      icon: Icons.label_outline_rounded,
      label: 'Auto-tag',
      resultTitle: 'Suggested Tags',
    ),
    _AiButton(
      icon: Icons.chat_bubble_outline_rounded,
      label: 'Ask AI',
      resultTitle: 'AI Response',
    ),
    _AiButton(
      icon: Icons.calculate_outlined,
      label: 'Calculate',
      resultTitle: 'Calculation Result',
    ),
  ];

  Future<void> _handleTap(int index) async {
    if (_loadingIndex != -1) return; // another action in progress

    final action = _actions[index];

    if (widget.onAction == null) {
      _showResultSheet(action.resultTitle, 'AI features coming soon.');
      return;
    }

    setState(() => _loadingIndex = index);

    try {
      final result = await widget.onAction!(action.label);
      if (mounted) _showResultSheet(action.resultTitle, result);
    } catch (e) {
      if (mounted) {
        _showResultSheet(action.resultTitle, 'Something went wrong: $e');
      }
    } finally {
      if (mounted) setState(() => _loadingIndex = -1);
    }
  }

  void _showResultSheet(String title, String content) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.75,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title row
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 20,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      // Close button
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.pop(context),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),

                  // Result content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        content,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          height: 1.7,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_actions.length, (i) {
              final action = _actions[i];
              final isLoading = _loadingIndex == i;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        )
                      : Icon(action.icon, size: 18, color: cs.primary),
                  label: Text(
                    action.label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.primary,
                    ),
                  ),
                  backgroundColor: cs.primary.withValues(alpha: 0.08),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  onPressed: isLoading ? null : () => _handleTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Internal data class for each AI button.
// AI NOTE: Internal data model for configuring individual AI action buttons.
class _AiButton {
  final IconData icon;
  final String label;
  final String resultTitle;

  const _AiButton({
    required this.icon,
    required this.label,
    required this.resultTitle,
  });
}
