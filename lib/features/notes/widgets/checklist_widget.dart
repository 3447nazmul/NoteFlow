import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Interactive Checklist Widget (Notion-style)
///
/// Features:
///   • Tap checkbox to check/uncheck with strikethrough animation
///   • Enter key adds new item below
///   • Backspace on empty item removes it
///   • Progress indicator: "X of Y completed"
///   • Follows Lumina Focus design tokens
/// ──────────────────────────────────────────────────────────────

// AI NOTE: A Notion-style interactive checklist widget for notes.
class ChecklistWidget extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final bool readOnly;

  const ChecklistWidget({
    super.key,
    required this.items,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<ChecklistWidget> createState() => _ChecklistWidgetState();
}

class _ChecklistWidgetState extends State<ChecklistWidget> {
  late List<Map<String, dynamic>> _items;
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(
      widget.items.map((m) => Map<String, dynamic>.from(m)),
    );
    _buildControllers();
  }

  @override
  void didUpdateWidget(ChecklistWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != _items.length) {
      _items = List<Map<String, dynamic>>.from(
        widget.items.map((m) => Map<String, dynamic>.from(m)),
      );
      _buildControllers();
    }
  }

  void _buildControllers() {
    // Dispose old controllers
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();

    for (final item in _items) {
      _controllers.add(
        TextEditingController(text: item['text'] as String? ?? ''),
      );
      _focusNodes.add(FocusNode());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _emitChange() {
    widget.onChanged(
      List<Map<String, dynamic>>.from(
        _items.map((m) => Map<String, dynamic>.from(m)),
      ),
    );
  }

  void _toggleItem(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _items[index]['checked'] = !(_items[index]['checked'] as bool? ?? false);
    });
    _emitChange();
  }

  void _updateText(int index, String text) {
    _items[index]['text'] = text;
    _emitChange();
  }

  void _addItemBelow(int index) {
    final newItem = {'text': '', 'checked': false};
    setState(() {
      _items.insert(index + 1, newItem);
      _controllers.insert(index + 1, TextEditingController());
      _focusNodes.insert(index + 1, FocusNode());
    });
    _emitChange();

    // Focus the new item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index + 1 < _focusNodes.length) {
        _focusNodes[index + 1].requestFocus();
      }
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return; // Keep at least one item
    setState(() {
      _items.removeAt(index);
      _controllers[index].dispose();
      _controllers.removeAt(index);
      _focusNodes[index].dispose();
      _focusNodes.removeAt(index);
    });
    _emitChange();

    // Focus previous item
    if (index > 0 && index - 1 < _focusNodes.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[index - 1].requestFocus();
        _controllers[index - 1].selection = TextSelection.collapsed(
          offset: _controllers[index - 1].text.length,
        );
      });
    }
  }

  void _addNewItem() {
    final newItem = {'text': '', 'checked': false};
    setState(() {
      _items.add(newItem);
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    });
    _emitChange();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes.last.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completed = _items.where((i) => i['checked'] == true).length;
    final total = _items.length;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header with progress ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(Icons.checklist_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Checklist',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                // Progress
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: completed == total && total > 0
                        ? Colors.green.withValues(alpha: 0.12)
                        : cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    '$completed of $total',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: completed == total && total > 0
                          ? Colors.green.shade700
                          : cs.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Progress bar ──
          if (total > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? completed / total : 0,
                  minHeight: 3,
                  backgroundColor: cs.outlineVariant.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completed == total && total > 0 ? Colors.green : cs.primary,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // ── Items ──
          ...List.generate(_items.length, (index) {
            final item = _items[index];
            final checked = item['checked'] as bool? ?? false;

            return _ChecklistItem(
              checked: checked,
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              readOnly: widget.readOnly,
              onToggle: () => _toggleItem(index),
              onTextChanged: (text) => _updateText(index, text),
              onSubmitted: () => _addItemBelow(index),
              onBackspaceEmpty: () => _removeItem(index),
            );
          }),

          // ── Add item button ──
          if (!widget.readOnly)
            InkWell(
              onTap: _addNewItem,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: cs.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Add item',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Single Checklist Item
/// ──────────────────────────────────────────────────────────────

// AI NOTE: A single row item in the checklist, handling text input and check state.
class _ChecklistItem extends StatelessWidget {
  final bool checked;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool readOnly;
  final VoidCallback onToggle;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onBackspaceEmpty;

  const _ChecklistItem({
    required this.checked,
    required this.controller,
    required this.focusNode,
    required this.readOnly,
    required this.onToggle,
    required this.onTextChanged,
    required this.onSubmitted,
    required this.onBackspaceEmpty,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Checkbox ──
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(left: 8, right: 4),
              decoration: BoxDecoration(
                color: checked ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? cs.primary : cs.outlineVariant,
                  width: 2,
                ),
              ),
              child: checked
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),

          // ── Text field ──
          Expanded(
            child: readOnly
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Text(
                      controller.text,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        height: 1.5,
                        color: checked
                            ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                            : cs.onSurface,
                        decoration: checked ? TextDecoration.lineThrough : null,
                        decorationColor: cs.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  )
                : KeyboardListener(
                    focusNode: FocusNode(), // Wrapper focus node
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.backspace &&
                          controller.text.isEmpty) {
                        onBackspaceEmpty();
                      }
                    },
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onTextChanged,
                      onSubmitted: (_) => onSubmitted(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        height: 1.5,
                        color: checked
                            ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                            : cs.onSurface,
                        decoration: checked ? TextDecoration.lineThrough : null,
                        decorationColor: cs.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Task…',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
