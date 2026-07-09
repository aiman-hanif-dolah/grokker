import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

/// Cera Pro substitute per [styles/DESIGN.md].
abstract final class GrokkerTypography {
  static String get fontFamily => GoogleFonts.dmSans().fontFamily!;

  static TextStyle caption({Color color = GrokkerColors.slate}) => GoogleFonts.dmSans(
    fontSize: 10,
    height: 1.6,
    letterSpacing: 1,
    fontWeight: FontWeight.w500,
    color: color,
  );

  static TextStyle eyebrow({Color color = GrokkerColors.slate}) => GoogleFonts.dmSans(
    fontSize: 10,
    height: 1.6,
    letterSpacing: 1.0,
    fontWeight: FontWeight.w500,
    color: color,
  );

  static TextStyle bodySm({Color color = GrokkerColors.fog}) => GoogleFonts.dmSans(
    fontSize: 14,
    height: 1.43,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle body({Color color = GrokkerColors.fog}) => GoogleFonts.dmSans(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle label({Color color = GrokkerColors.fog}) => GoogleFonts.dmSans(
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: color,
  );

  static TextStyle subheading({Color color = GrokkerColors.fog}) => GoogleFonts.dmSans(
    fontSize: 18,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle headingSm({Color color = GrokkerColors.white}) => GoogleFonts.dmSans(
    fontSize: 24,
    height: 1.33,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle heading({Color color = GrokkerColors.white}) => GoogleFonts.dmSans(
    fontSize: 32,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle display({Color color = GrokkerColors.white}) => GoogleFonts.dmSans(
    fontSize: 44,
    height: 1.14,
    letterSpacing: -0.88,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle mono({
    double size = 12,
    Color color = GrokkerColors.ash,
  }) => TextStyle(
    fontFamily: 'Menlo',
    fontSize: size,
    height: 1.43,
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
      fontWeight: FontWeight.w700,
      color: GrokkerColors.white,
    ),
    titleLarge: GoogleFonts.dmSans(
      fontSize: 18,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: GrokkerColors.white,
    ),
    titleMedium: label(color: GrokkerColors.white),
    titleSmall: bodySm(color: GrokkerColors.ash),
    bodyLarge: body(),
    bodyMedium: bodySm(),
    bodySmall: caption(color: GrokkerColors.ash),
    labelLarge: label(color: GrokkerColors.white),
    labelMedium: bodySm(color: GrokkerColors.fog),
    labelSmall: caption(),
  );
}