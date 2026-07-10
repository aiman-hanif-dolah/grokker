import 'package:flutter/material.dart';

/// Design tokens from [styles/tokens.json] / [styles/DESIGN.md] (Awesomic).
///
/// Zinc-neutral scale + ember accent. Dark surfaces used for the terminal shell;
/// light surfaces for settings and light theme mode.
abstract final class GrokkerColors {
  // ── Canonical Awesomic scale ──────────────────────────────────────────
  static const obsidian = Color(0xFF09090B);
  static const graphite = Color(0xFF18181B);

  /// Design `--color-slate` surface (#27272a). Prefer [zincSlate] in new code.
  static const zincSlate = Color(0xFF27272A);
  static const iron = Color(0xFF3F3F46);
  static const steel = Color(0xFF52525B);
  static const fog = Color(0xFF71717A);
  static const ash = Color(0xFFA1A1AA);
  static const mist = Color(0xFFD4D4D8);
  static const cloud = Color(0xFFECECEE);
  static const paper = Color(0xFFF4F4F5);
  static const snow = Color(0xFFFFFFFF);
  static const ember = Color(0xFFFF5A00);
  static const magentaSpark = Color(0xFFFE45E2);

  /// Slightly lifted ember for hover / bright prompt accents.
  static const emberBright = Color(0xFFFF7A33);
  static const emberDeep = Color(0xFFCC4800);

  // Functional status (app-only; not brand accents)
  static const mapGreen = Color(0xFF16A34A);
  static const mapGreenMuted = Color(0xFF15803D);
  static const errorRed = Color(0xFFDC2626);
  static const errorRedMuted = Color(0xFF7F1D1D);
  static const warningAmber = Color(0xFFD97706);

  // ── Back-compat aliases (old Mapbox names → Awesomic) ─────────────────
  /// Tertiary / helper text (maps to design fog — old code used slate as text).
  static const slate = fog;
  static const voidBlack = obsidian;
  static const deepCharcoal = graphite;
  static const gunmetal = zincSlate;
  static const pewter = iron;
  static const silver = mist;
  static const white = snow;
  static const signalBlue = ember;
  static const signalBlueBright = emberBright;
  static const deepSignal = emberDeep;
}

abstract final class GrokkerSurfaces {
  /// Dark terminal canvas (obsidian).
  static const voidFloor = GrokkerColors.obsidian;

  /// Sidebar / elevated panels (graphite).
  static const deepPanel = GrokkerColors.graphite;

  /// Inputs, chips, raised rows (zinc slate).
  static const raised = GrokkerColors.zincSlate;

  /// Overlays / menus (iron).
  static const overlay = GrokkerColors.iron;

  static const elevated = GrokkerColors.zincSlate;

  // Light-theme surfaces
  static const canvas = GrokkerColors.paper;
  static const card = GrokkerColors.snow;
  static const subtleCard = Color(0xFFFAFAFA);
}

abstract final class GrokkerGradients {
  /// Primary dark CTA sheen (obsidian → graphite).
  static const signalGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [GrokkerColors.obsidian, GrokkerColors.graphite],
  );

  static const emberGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [GrokkerColors.ember, GrokkerColors.emberDeep],
  );

  static const panelSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x0AFFFFFF), Color(0x00FFFFFF)],
  );

  static const accentStrip = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [GrokkerColors.emberBright, GrokkerColors.emberDeep],
  );
}

abstract final class GrokkerShadows {
  /// Soft ember/status glow (sparingly).
  static List<BoxShadow> glow(Color color, {double blur = 16}) => [
    BoxShadow(
      color: color.withValues(alpha: 0.28),
      blurRadius: blur,
      spreadRadius: 0,
    ),
  ];

  /// Awesomic primary button inset ring.
  static const darkCta = [
    BoxShadow(
      color: Color(0x80FFFFFF),
      blurRadius: 0,
      offset: Offset(0, 0.5),
      spreadRadius: 0,
      blurStyle: BlurStyle.inner,
    ),
    BoxShadow(color: Color(0x24000000), blurRadius: 6, offset: Offset(0, 4)),
  ];

  static const md = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// Prefer hairline borders over shadows on cards.
  static const panel = <BoxShadow>[];
}

abstract final class GrokkerSpacing {
  static const unit = 4.0;
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s28 = 28.0;
  static const s32 = 32.0;
  static const s36 = 36.0;
  static const s40 = 40.0;
  static const s48 = 48.0;
  static const s64 = 64.0;
  static const s68 = 68.0;
  static const s80 = 80.0;
  static const s120 = 120.0;
  static const cardPadding = 16.0;
  static const elementGap = 8.0;
  static const navHeight = 48.0;
  static const sidebarWidth = 260.0;
  static const inspectorWidth = 300.0;
  static const chatMaxWidth = 960.0;
}

abstract final class GrokkerRadius {
  /// Dense desktop chrome (Awesomic radii scaled down for app panels).
  static const badge = 10.0;
  static const input = 12.0;
  static const button = 12.0;
  static const chip = 10.0;
  static const card = 14.0;
  static const panel = 14.0;
  static const icons = 32.0;
  static const pill = 1000.0;
}

abstract final class GrokkerLayout {
  static const pageMaxWidth = 1200.0;
  static const sectionGap = 80.0;
}
