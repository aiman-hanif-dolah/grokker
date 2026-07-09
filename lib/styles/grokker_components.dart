import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'grokker_typography.dart';

class GrokkerEyebrow extends StatelessWidget {
  const GrokkerEyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GrokkerTypography.eyebrow(color: color ?? GrokkerColors.slate),
    );
  }
}

class GrokkerBadge extends StatelessWidget {
  const GrokkerBadge({
    super.key,
    required this.label,
    this.variant = GrokkerBadgeVariant.info,
    this.icon,
  });

  final String label;
  final GrokkerBadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      GrokkerBadgeVariant.success => (
        GrokkerColors.mapGreen.withValues(alpha: 0.15),
        GrokkerColors.mapGreen,
        GrokkerColors.mapGreen.withValues(alpha: 0.3),
      ),
      GrokkerBadgeVariant.info => (
        GrokkerColors.signalBlue.withValues(alpha: 0.15),
        GrokkerColors.signalBlueBright,
        GrokkerColors.signalBlue.withValues(alpha: 0.3),
      ),
      GrokkerBadgeVariant.error => (
        GrokkerColors.errorRed.withValues(alpha: 0.15),
        GrokkerColors.errorRed,
        GrokkerColors.errorRed.withValues(alpha: 0.3),
      ),
      GrokkerBadgeVariant.neutral => (
        GrokkerColors.graphite,
        GrokkerColors.fog,
        GrokkerColors.pewter,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GrokkerSpacing.s8,
        vertical: GrokkerSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(GrokkerRadius.badge),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: GrokkerSpacing.s4),
          ],
          Text(
            label.toUpperCase(),
            style: GrokkerTypography.caption(color: fg),
          ),
        ],
      ),
    );
  }
}

enum GrokkerBadgeVariant { success, info, error, neutral }

class GrokkerPrimaryButton extends StatelessWidget {
  const GrokkerPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.dense = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dense;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final child = icon == null
        ? Text(label, style: GrokkerTypography.label(color: GrokkerColors.white))
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: GrokkerColors.white),
              const SizedBox(width: GrokkerSpacing.s8),
              Text(
                label,
                style: GrokkerTypography.label(color: GrokkerColors.white),
              ),
            ],
          );

    final button = DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? GrokkerGradients.signalGlow : null,
        color: enabled ? null : GrokkerColors.steel,
        borderRadius: BorderRadius.circular(GrokkerRadius.pill),
        boxShadow: enabled ? GrokkerShadows.glow(GrokkerColors.signalBlue, blur: 12) : null,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: GrokkerColors.white,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: GrokkerColors.slate,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: dense ? GrokkerSpacing.s16 : GrokkerSpacing.s24,
            vertical: dense ? GrokkerSpacing.s8 : GrokkerSpacing.s12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GrokkerRadius.pill),
          ),
          elevation: 0,
        ),
        child: child,
      ),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class GrokkerOutlinedButton extends StatelessWidget {
  const GrokkerOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.dense = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dense;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: GrokkerColors.white,
        side: const BorderSide(color: GrokkerColors.pewter),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? GrokkerSpacing.s16 : GrokkerSpacing.s24,
          vertical: dense ? GrokkerSpacing.s8 : GrokkerSpacing.s12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.pill),
        ),
      ),
      child: icon == null
          ? Text(label, style: GrokkerTypography.label(color: GrokkerColors.white))
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: GrokkerSpacing.s8),
                Text(
                  label,
                  style: GrokkerTypography.label(color: GrokkerColors.white),
                ),
              ],
            ),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class GrokkerGhostButton extends StatelessWidget {
  const GrokkerGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.accent = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? GrokkerColors.signalBlueBright : GrokkerColors.fog;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(
          horizontal: GrokkerSpacing.s8,
          vertical: GrokkerSpacing.s4,
        ),
      ),
      child: icon == null
          ? Text(label, style: GrokkerTypography.label(color: color))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: GrokkerSpacing.s4),
                Text(label, style: GrokkerTypography.label(color: color)),
              ],
            ),
    );
  }
}

class GrokkerIconFrameButton extends StatelessWidget {
  const GrokkerIconFrameButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 34,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: accent
          ? GrokkerColors.signalBlue.withValues(alpha: 0.12)
          : GrokkerSurfaces.raised,
      borderRadius: BorderRadius.circular(GrokkerRadius.input),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(GrokkerRadius.input),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GrokkerRadius.input),
            border: Border.all(
              color: accent
                  ? GrokkerColors.signalBlue.withValues(alpha: 0.4)
                  : GrokkerColors.pewter,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: accent ? GrokkerColors.signalBlueBright : GrokkerColors.fog,
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class GrokkerPanel extends StatelessWidget {
  const GrokkerPanel({
    super.key,
    required this.child,
    this.padding,
    this.radius = GrokkerRadius.card,
    this.color = GrokkerSurfaces.deepPanel,
    this.border,
    this.accentStrip = false,
    this.accentColor = GrokkerColors.signalBlue,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color color;
  final BorderSide? border;
  final bool accentStrip;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.fromBorderSide(border!),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            if (accentStrip)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accentColor,
                        accentColor.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: padding ?? const EdgeInsets.all(GrokkerSpacing.cardPadding),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class GrokkerSection extends StatelessWidget {
  const GrokkerSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.icon,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GrokkerSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: GrokkerColors.slate),
                const SizedBox(width: GrokkerSpacing.s8),
              ],
              GrokkerEyebrow(title),
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: GrokkerSpacing.s12),
          child,
        ],
      ),
    );
  }
}

class GrokkerFilterPill extends StatelessWidget {
  const GrokkerFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? GrokkerColors.signalBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(GrokkerRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GrokkerRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: GrokkerSpacing.s16,
            vertical: GrokkerSpacing.s8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GrokkerRadius.pill),
            border: selected
                ? null
                : Border.all(color: GrokkerColors.pewter),
            boxShadow: selected
                ? GrokkerShadows.glow(GrokkerColors.signalBlue, blur: 8)
                : null,
          ),
          child: Text(
            label,
            style: GrokkerTypography.label(
              color: selected ? GrokkerColors.white : GrokkerColors.fog,
            ),
          ),
        ),
      ),
    );
  }
}

class GrokkerSurfaceDivider extends StatelessWidget {
  const GrokkerSurfaceDivider({super.key, this.vertical = false});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return Container(
        width: 1,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x00FFFFFF),
              Color(0x18FFFFFF),
              Color(0x00FFFFFF),
            ],
          ),
        ),
      );
    }
    return Container(
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x00FFFFFF),
            Color(0x18FFFFFF),
            Color(0x00FFFFFF),
          ],
        ),
      ),
    );
  }
}

class GrokkerMetaChip extends StatelessWidget {
  const GrokkerMetaChip({
    super.key,
    required this.label,
    this.icon,
    this.color = GrokkerColors.fog,
  });

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GrokkerSpacing.s8,
        vertical: GrokkerSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: GrokkerSurfaces.raised,
        borderRadius: BorderRadius.circular(GrokkerRadius.badge),
        border: Border.all(color: GrokkerColors.pewter.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: GrokkerSpacing.s4),
          ],
          Text(label, style: GrokkerTypography.caption(color: color)),
        ],
      ),
    );
  }
}

class GrokkerAvatar extends StatelessWidget {
  const GrokkerAvatar({
    super.key,
    required this.icon,
    this.color = GrokkerColors.signalBlue,
    this.size = 32,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

class GrokkerSearchField extends StatelessWidget {
  const GrokkerSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GrokkerTypography.bodySm(color: GrokkerColors.fog),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GrokkerTypography.bodySm(color: GrokkerColors.slate),
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: GrokkerColors.slate),
        filled: true,
        fillColor: GrokkerSurfaces.raised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GrokkerSpacing.s12,
          vertical: GrokkerSpacing.s12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.chip),
          borderSide: BorderSide(color: GrokkerColors.pewter.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.chip),
          borderSide: BorderSide(color: GrokkerColors.pewter.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.chip),
          borderSide: const BorderSide(color: GrokkerColors.signalBlue, width: 1.5),
        ),
        isDense: true,
      ),
    );
  }
}