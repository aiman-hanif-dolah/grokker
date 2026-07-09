import 'package:flutter/material.dart';

import '../shared/models/app_settings.dart';
import '../styles/design_tokens.dart';
import '../styles/grokker_typography.dart';

class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData fromSettings(AppSettings settings) {
    switch (settings.themeMode) {
      case AppThemeMode.dark:
      case AppThemeMode.system:
        return dark();
      case AppThemeMode.light:
        return light();
    }
  }

  static ThemeData _build(Brightness brightness) {
    // Design system is dark-first; light mode uses softened dark palette.
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? GrokkerSurfaces.voidFloor : const Color(0xFFF0F2F6);
    final surface = isDark ? GrokkerSurfaces.deepPanel : Colors.white;
    final raised = isDark ? GrokkerSurfaces.raised : const Color(0xFFE8EBF0);
    final border = isDark ? GrokkerColors.gunmetal : GrokkerColors.cloud;
    final body = isDark ? GrokkerColors.fog : const Color(0xFF3D4654);
    final heading = isDark ? GrokkerColors.white : const Color(0xFF0E1012);
    final subtle = isDark ? GrokkerColors.ash : const Color(0xFF566171);

    final textTheme = GrokkerTypography.textTheme().apply(
      bodyColor: body,
      displayColor: heading,
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      fontFamily: GrokkerTypography.fontFamily,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: GrokkerColors.signalBlue,
        onPrimary: GrokkerColors.white,
        secondary: GrokkerColors.deepSignal,
        onSecondary: GrokkerColors.white,
        surface: surface,
        onSurface: body,
        error: GrokkerColors.slate,
        onError: GrokkerColors.white,
      ),
      dividerColor: border,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: heading,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GrokkerTypography.label(color: heading),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? GrokkerSurfaces.raised : const Color(0xFFF5F6F8),
        hintStyle: GrokkerTypography.bodySm(color: subtle),
        labelStyle: GrokkerTypography.caption(color: subtle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.input),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.input),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.input),
          borderSide: const BorderSide(color: GrokkerColors.signalBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GrokkerSpacing.s12,
          vertical: GrokkerSpacing.s12,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: raised,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GrokkerRadius.input),
            borderSide: BorderSide(color: border),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: GrokkerSpacing.s12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.chip),
        ),
        selectedTileColor: GrokkerColors.signalBlue.withValues(alpha: 0.15),
        iconColor: GrokkerColors.fog,
        textColor: body,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: GrokkerSurfaces.overlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.chip),
        ),
        textStyle: GrokkerTypography.bodySm(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GrokkerSurfaces.deepPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.card),
        ),
        titleTextStyle: GrokkerTypography.headingSm(),
      ),
      iconTheme: const IconThemeData(
        color: GrokkerColors.fog,
        size: 18,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GrokkerColors.white;
          }
          return GrokkerColors.silver;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GrokkerColors.signalBlue;
          }
          return GrokkerColors.steel;
        }),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      extensions: [
        GrokkerThemeExtension(
          monoFamily: 'Menlo',
          panelBorder: border,
          accent: GrokkerColors.signalBlue,
          subtleText: subtle,
          surfaceRaised: raised,
          surfaceOverlay: isDark ? GrokkerSurfaces.overlay : const Color(0xFFE0E4EA),
          bodyText: body,
          headingText: heading,
        ),
      ],
    );
  }
}

class GrokkerThemeExtension extends ThemeExtension<GrokkerThemeExtension> {
  const GrokkerThemeExtension({
    required this.monoFamily,
    required this.panelBorder,
    required this.accent,
    required this.subtleText,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.bodyText,
    required this.headingText,
  });

  final String monoFamily;
  final Color panelBorder;
  final Color accent;
  final Color subtleText;
  final Color surfaceRaised;
  final Color surfaceOverlay;
  final Color bodyText;
  final Color headingText;

  static GrokkerThemeExtension of(BuildContext context) {
    return Theme.of(context).extension<GrokkerThemeExtension>()!;
  }

  @override
  GrokkerThemeExtension copyWith({
    String? monoFamily,
    Color? panelBorder,
    Color? accent,
    Color? subtleText,
    Color? surfaceRaised,
    Color? surfaceOverlay,
    Color? bodyText,
    Color? headingText,
  }) {
    return GrokkerThemeExtension(
      monoFamily: monoFamily ?? this.monoFamily,
      panelBorder: panelBorder ?? this.panelBorder,
      accent: accent ?? this.accent,
      subtleText: subtleText ?? this.subtleText,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      bodyText: bodyText ?? this.bodyText,
      headingText: headingText ?? this.headingText,
    );
  }

  @override
  GrokkerThemeExtension lerp(
    covariant ThemeExtension<GrokkerThemeExtension>? other,
    double t,
  ) {
    return this;
  }
}