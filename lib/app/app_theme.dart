import 'package:flutter/material.dart';

import '../shared/models/app_settings.dart';
import '../styles/design_tokens.dart';
import '../styles/grokker_typography.dart';

class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  /// Prefer [MaterialApp.theme] + [MaterialApp.darkTheme] + [themeModeOf].
  static ThemeData fromSettings(AppSettings settings) {
    return settings.themeMode == AppThemeMode.light ? light() : dark();
  }

  /// Dark is default; light only when explicitly chosen.
  static ThemeMode themeModeOf(AppSettings settings) {
    return settings.themeMode == AppThemeMode.light
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Dark (default) = zinc terminal. Light (optional) = paper/snow.
    final bg = isDark ? GrokkerSurfaces.voidFloor : GrokkerSurfaces.canvas;
    final surface = isDark ? GrokkerSurfaces.deepPanel : GrokkerSurfaces.card;
    final raised = isDark ? GrokkerSurfaces.raised : GrokkerSurfaces.subtleCard;
    final border = isDark ? GrokkerColors.iron : GrokkerColors.cloud;
    final body = isDark ? GrokkerColors.ash : GrokkerColors.graphite;
    final heading = isDark ? GrokkerColors.snow : GrokkerColors.obsidian;
    final subtle = isDark ? GrokkerColors.fog : GrokkerColors.steel;
    final mono = isDark ? GrokkerColors.mist : GrokkerColors.graphite;

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
        primary: GrokkerColors.ember,
        onPrimary: GrokkerColors.snow,
        secondary: isDark ? GrokkerColors.zincSlate : GrokkerColors.obsidian,
        onSecondary: GrokkerColors.snow,
        surface: surface,
        onSurface: body,
        error: GrokkerColors.errorRed,
        onError: GrokkerColors.snow,
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
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? raised : GrokkerSurfaces.card,
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
          borderSide: const BorderSide(color: GrokkerColors.ember, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GrokkerSpacing.s16,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GrokkerSpacing.s12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.chip),
        ),
        selectedTileColor: GrokkerColors.ember.withValues(alpha: 0.12),
        iconColor: subtle,
        textColor: body,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? raised : GrokkerSurfaces.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.chip),
          side: BorderSide(color: border),
        ),
        textStyle: GrokkerTypography.bodySm(color: body),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.card),
          side: BorderSide(color: border),
        ),
        titleTextStyle: GrokkerTypography.headingSm(color: heading),
      ),
      iconTheme: IconThemeData(color: subtle, size: 18),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GrokkerColors.snow;
          }
          return isDark ? GrokkerColors.mist : GrokkerColors.steel;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GrokkerColors.ember;
          }
          return isDark ? GrokkerColors.iron : GrokkerColors.mist;
        }),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      extensions: [
        GrokkerThemeExtension(
          isDark: isDark,
          monoFamily: 'JetBrains Mono',
          canvas: bg,
          panel: surface,
          raised: raised,
          panelBorder: border,
          accent: GrokkerColors.ember,
          subtleText: subtle,
          surfaceRaised: raised,
          surfaceOverlay: isDark ? GrokkerSurfaces.overlay : GrokkerColors.mist,
          bodyText: body,
          headingText: heading,
          monoText: mono,
        ),
      ],
    );
  }
}

class GrokkerThemeExtension extends ThemeExtension<GrokkerThemeExtension> {
  const GrokkerThemeExtension({
    required this.isDark,
    required this.monoFamily,
    required this.canvas,
    required this.panel,
    required this.raised,
    required this.panelBorder,
    required this.accent,
    required this.subtleText,
    required this.surfaceRaised,
    required this.surfaceOverlay,
    required this.bodyText,
    required this.headingText,
    required this.monoText,
  });

  final bool isDark;
  final String monoFamily;
  final Color canvas;
  final Color panel;
  final Color raised;
  final Color panelBorder;
  final Color accent;
  final Color subtleText;
  final Color surfaceRaised;
  final Color surfaceOverlay;
  final Color bodyText;
  final Color headingText;
  final Color monoText;

  static GrokkerThemeExtension of(BuildContext context) {
    return Theme.of(context).extension<GrokkerThemeExtension>()!;
  }

  @override
  GrokkerThemeExtension copyWith({
    bool? isDark,
    String? monoFamily,
    Color? canvas,
    Color? panel,
    Color? raised,
    Color? panelBorder,
    Color? accent,
    Color? subtleText,
    Color? surfaceRaised,
    Color? surfaceOverlay,
    Color? bodyText,
    Color? headingText,
    Color? monoText,
  }) {
    return GrokkerThemeExtension(
      isDark: isDark ?? this.isDark,
      monoFamily: monoFamily ?? this.monoFamily,
      canvas: canvas ?? this.canvas,
      panel: panel ?? this.panel,
      raised: raised ?? this.raised,
      panelBorder: panelBorder ?? this.panelBorder,
      accent: accent ?? this.accent,
      subtleText: subtleText ?? this.subtleText,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      bodyText: bodyText ?? this.bodyText,
      headingText: headingText ?? this.headingText,
      monoText: monoText ?? this.monoText,
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
