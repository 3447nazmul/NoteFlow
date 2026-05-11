import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Lumina Focus Colour Tokens
///
/// Every hex value is extracted from DESIGN.md (Stitch export).
/// Light-mode tokens are un-prefixed. Dark-mode tokens are
/// prefixed with `dark`.
/// ──────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // ─── Override / Brand Colours ───
  static const Color brandIndigo = Color(0xFF6366F1);

  // ═══════════════════════════════════════════════════════════
  //  LIGHT MODE  —  Lumina Focus
  // ═══════════════════════════════════════════════════════════

  // Primary
  static const Color primary = Color(0xFF4648D4);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF6063EE);
  static const Color onPrimaryContainer = Color(0xFFFFFBFF);
  static const Color inversePrimary = Color(0xFFC0C1FF);

  // Primary Fixed
  static const Color primaryFixed = Color(0xFFE1E0FF);
  static const Color primaryFixedDim = Color(0xFFC0C1FF);
  static const Color onPrimaryFixed = Color(0xFF07006C);
  static const Color onPrimaryFixedVariant = Color(0xFF2F2EBE);

  // Secondary
  static const Color secondary = Color(0xFF516072);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD2E1F7);
  static const Color onSecondaryContainer = Color(0xFF556477);

  // Secondary Fixed
  static const Color secondaryFixed = Color(0xFFD4E4FA);
  static const Color secondaryFixedDim = Color(0xFFB9C8DE);
  static const Color onSecondaryFixed = Color(0xFF0D1C2D);
  static const Color onSecondaryFixedVariant = Color(0xFF39485A);

  // Tertiary
  static const Color tertiary = Color(0xFF904900);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFB55D00);
  static const Color onTertiaryContainer = Color(0xFFFFFBFF);

  // Tertiary Fixed
  static const Color tertiaryFixed = Color(0xFFFFDCC5);
  static const Color tertiaryFixedDim = Color(0xFFFFB783);
  static const Color onTertiaryFixed = Color(0xFF301400);
  static const Color onTertiaryFixedVariant = Color(0xFF703700);

  // Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Surface
  static const Color surface = Color(0xFFFCF8FF);
  static const Color onSurface = Color(0xFF1B1B23);
  static const Color onSurfaceVariant = Color(0xFF464554);
  static const Color surfaceDim = Color(0xFFDBD8E4);
  static const Color surfaceBright = Color(0xFFFCF8FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF5F2FE);
  static const Color surfaceContainer = Color(0xFFEFECF8);
  static const Color surfaceContainerHigh = Color(0xFFE9E6F3);
  static const Color surfaceContainerHighest = Color(0xFFE4E1ED);
  static const Color surfaceVariant = Color(0xFFE4E1ED);
  static const Color surfaceTint = Color(0xFF494BD6);

  // Inverse
  static const Color inverseSurface = Color(0xFF303038);
  static const Color inverseOnSurface = Color(0xFFF2EFFB);

  // Outline
  static const Color outline = Color(0xFF767586);
  static const Color outlineVariant = Color(0xFFC7C4D7);

  // Background (alias for surface in M3)
  static const Color background = Color(0xFFFCF8FF);
  static const Color onBackground = Color(0xFF1B1B23);

  // ═══════════════════════════════════════════════════════════
  //  DARK MODE  —  Lumina Focus Dark
  // ═══════════════════════════════════════════════════════════

  // Primary
  static const Color darkPrimary = Color(0xFFC0C1FF);
  static const Color darkOnPrimary = Color(0xFF1000A9);
  static const Color darkPrimaryContainer = Color(0xFF8083FF);
  static const Color darkOnPrimaryContainer = Color(0xFF0D0096);
  static const Color darkInversePrimary = Color(0xFF494BD6);

  // Primary Fixed
  static const Color darkPrimaryFixed = Color(0xFFE1E0FF);
  static const Color darkPrimaryFixedDim = Color(0xFFC0C1FF);
  static const Color darkOnPrimaryFixed = Color(0xFF07006C);
  static const Color darkOnPrimaryFixedVariant = Color(0xFF2F2EBE);

  // Secondary
  static const Color darkSecondary = Color(0xFFB8C4FF);
  static const Color darkOnSecondary = Color(0xFF1A2B6A);
  static const Color darkSecondaryContainer = Color(0xFF334282);
  static const Color darkOnSecondaryContainer = Color(0xFFA2B1F9);

  // Secondary Fixed
  static const Color darkSecondaryFixed = Color(0xFFDDE1FF);
  static const Color darkSecondaryFixedDim = Color(0xFFB8C4FF);
  static const Color darkOnSecondaryFixed = Color(0xFF001354);
  static const Color darkOnSecondaryFixedVariant = Color(0xFF334282);

  // Tertiary
  static const Color darkTertiary = Color(0xFFBCC7DE);
  static const Color darkOnTertiary = Color(0xFF263143);
  static const Color darkTertiaryContainer = Color(0xFF8691A7);
  static const Color darkOnTertiaryContainer = Color(0xFF1F2A3C);

  // Tertiary Fixed
  static const Color darkTertiaryFixed = Color(0xFFD8E3FB);
  static const Color darkTertiaryFixedDim = Color(0xFFBCC7DE);
  static const Color darkOnTertiaryFixed = Color(0xFF111C2D);
  static const Color darkOnTertiaryFixedVariant = Color(0xFF3C475A);

  // Error
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkOnError = Color(0xFF690005);
  static const Color darkErrorContainer = Color(0xFF93000A);
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);

  // Surface
  static const Color darkSurface = Color(0xFF0B1326);
  static const Color darkOnSurface = Color(0xFFDAE2FD);
  static const Color darkOnSurfaceVariant = Color(0xFFC7C4D7);
  static const Color darkSurfaceDim = Color(0xFF0B1326);
  static const Color darkSurfaceBright = Color(0xFF31394D);
  static const Color darkSurfaceContainerLowest = Color(0xFF060E20);
  static const Color darkSurfaceContainerLow = Color(0xFF131B2E);
  static const Color darkSurfaceContainer = Color(0xFF171F33);
  static const Color darkSurfaceContainerHigh = Color(0xFF222A3D);
  static const Color darkSurfaceContainerHighest = Color(0xFF2D3449);
  static const Color darkSurfaceVariant = Color(0xFF2D3449);
  static const Color darkSurfaceTint = Color(0xFFC0C1FF);

  // Inverse
  static const Color darkInverseSurface = Color(0xFFDAE2FD);
  static const Color darkInverseOnSurface = Color(0xFF283044);

  // Outline
  static const Color darkOutline = Color(0xFF908FA0);
  static const Color darkOutlineVariant = Color(0xFF464554);

  // Background
  static const Color darkBackground = Color(0xFF0B1326);
  static const Color darkOnBackground = Color(0xFFDAE2FD);
}
