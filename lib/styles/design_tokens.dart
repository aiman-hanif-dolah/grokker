import 'package:flutter/material.dart';

/// Design tokens sourced from [styles/tokens.json] and [styles/variables.css].
abstract final class GrokkerColors {
  static const voidBlack = Color(0xFF0A0C0E);
  static const deepCharcoal = Color(0xFF12151A);
  static const gunmetal = Color(0xFF1A1E25);
  static const graphite = Color(0xFF232830);
  static const steel = Color(0xFF2E3440);
  static const pewter = Color(0xFF3D4554);
  static const slate = Color(0xFF566171);
  static const ash = Color(0xFF8B96AA);
  static const fog = Color(0xFFA0AABA);
  static const silver = Color(0xFFBBC2CE);
  static const cloud = Color(0xFFD5DAE2);
  static const white = Color(0xFFFFFFFF);
  static const signalBlue = Color(0xFF007AFC);
  static const signalBlueBright = Color(0xFF3D9AFF);
  static const deepSignal = Color(0xFF0062CA);
  static const mapGreen = Color(0xFF22C55E);
  static const mapGreenMuted = Color(0xFF228A56);
  static const errorRed = Color(0xFFEF4444);
  static const errorRedMuted = Color(0xFF7F1D1D);
  static const warningAmber = Color(0xFFF59E0B);
}

abstract final class GrokkerSurfaces {
  static const voidFloor = GrokkerColors.voidBlack;
  static const deepPanel = GrokkerColors.deepCharcoal;
  static const raised = GrokkerColors.gunmetal;
  static const overlay = GrokkerColors.graphite;
  static const elevated = Color(0xFF1E2229);
}

abstract final class GrokkerGradients {
  static const signalGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [GrokkerColors.signalBlue, GrokkerColors.deepSignal],
  );

  static const panelSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
  );

  static const accentStrip = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [GrokkerColors.signalBlueBright, GrokkerColors.deepSignal],
  );
}

abstract final class GrokkerShadows {
  static List<BoxShadow> glow(Color color, {double blur = 16}) => [
    BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: blur, spreadRadius: 0),
  ];

  static const panel = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
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
  static const s40 = 40.0;
  static const s48 = 48.0;
  static const s60 = 60.0;
  static const s64 = 64.0;
  static const s96 = 96.0;
  static const cardPadding = 20.0;
  static const elementGap = 12.0;
  static const navHeight = 56.0;
  static const sidebarWidth = 300.0;
  static const inspectorWidth = 360.0;
  static const chatMaxWidth = 820.0;
}

abstract final class GrokkerRadius {
  static const badge = 6.0;
  static const input = 10.0;
  static const chip = 14.0;
  static const card = 18.0;
  static const panel = 20.0;
  static const pill = 100.0;
}

abstract final class GrokkerLayout {
  static const pageMaxWidth = 1344.0;
  static const sectionGap = 96.0;
}