import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// AI NOTE: A reusable widget that displays the NoteFlow logo and branding text with a gradient mask.
class LogoWidget extends StatelessWidget {
  final double iconSize;
  final double fontSize;

  const LogoWidget({super.key, this.iconSize = 36, this.fontSize = 32});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.edit_document,
            size: iconSize,
            color: Colors.white, // Color is ignored due to ShaderMask
          ),
          const SizedBox(width: 8),
          Text(
            'NoteFlow',
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
