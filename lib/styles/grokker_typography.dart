import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

/// Cosmica substitute (DM Sans) per [styles/DESIGN.md].
abstract final class GrokkerTypography {
  static String get fontFamily => GoogleFonts.dmSans().fontFamily!;

  static TextStyle caption({Color color = GrokkerColors.fog}) =>
      GoogleFonts.dmSans(
        fontSize: 12,
        height: 1.64,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle eyebrow({Color color = GrokkerColors.fog}) =>
      GoogleFonts.dmSans(
        fontSize: 12,
        height: 1.4,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle bodySm({Color color = GrokkerColors.ash}) =>
      GoogleFonts.dmSans(
        fontSize: 13,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle body({Color color = GrokkerColors.mist}) =>
      GoogleFonts.dmSans(
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle label({Color color = GrokkerColors.mist}) =>
      GoogleFonts.dmSans(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle subheading({Color color = GrokkerColors.snow}) =>
      GoogleFonts.dmSans(
        fontSize: 20,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle headingSm({Color color = GrokkerColors.snow}) =>
      GoogleFonts.dmSans(
        fontSize: 24,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle heading({Color color = GrokkerColors.snow}) =>
      GoogleFonts.dmSans(
        fontSize: 32,
        height: 1.28,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle display({Color color = GrokkerColors.snow}) =>
      GoogleFonts.dmSans(
        fontSize: 40,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle mono({double size = 13, Color color = GrokkerColors.ash}) =>
      TextStyle(
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: const [
          'Cascadia Mono',
          'Cascadia Code',
          'Consolas',
          'Menlo',
          'monospace',
        ],
        fontSize: size,
        height: 1.5,
        color: color,
      );

  static TextTheme textTheme() => TextTheme(
    displayLarge: display(),
    displayMedium: heading(),
    displaySmall: headingSm(),
    headlineLarge: heading(),
    headlineMedium: headingSm(),
    headlineSmall: GoogleFonts.dmSans(
      fontSize: 20,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: GrokkerColors.snow,
    ),
    titleLarge: GoogleFonts.dmSans(
      fontSize: 18,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: GrokkerColors.snow,
    ),
    titleMedium: label(color: GrokkerColors.snow),
    titleSmall: bodySm(color: GrokkerColors.ash),
    bodyLarge: body(),
    bodyMedium: bodySm(),
    bodySmall: caption(color: GrokkerColors.fog),
    labelLarge: label(color: GrokkerColors.snow),
    labelMedium: bodySm(color: GrokkerColors.ash),
    labelSmall: caption(),
  );
}
