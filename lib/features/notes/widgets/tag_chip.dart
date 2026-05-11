import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// AI NOTE: A pill-shaped UI component used to display tags in the editor and detail screens.
class TagChip extends StatelessWidget {
  final String label;
  final VoidCallback? onDeleted;

  const TagChip({super.key, required this.label, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Chip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: cs.primary,
        ),
      ),
      backgroundColor: cs.primary.withValues(alpha: 0.1),
      deleteIcon: onDeleted != null
          ? Icon(Icons.close_rounded, size: 14, color: cs.primary)
          : null,
      onDeleted: onDeleted,
      shape: const StadiumBorder(),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
