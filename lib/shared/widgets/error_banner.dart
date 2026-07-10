import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/errors/app_error.dart';
import '../../styles/design_tokens.dart';
import '../../styles/grokker_components.dart';
import '../../styles/grokker_typography.dart';

class ErrorBanner extends StatefulWidget {
  const ErrorBanner({super.key, required this.error});

  final AppError error;

  @override
  State<ErrorBanner> createState() => _ErrorBannerState();
}

class _ErrorBannerState extends State<ErrorBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = GrokkerThemeExtension.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GrokkerSpacing.s24,
        GrokkerSpacing.s16,
        GrokkerSpacing.s24,
        0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: GrokkerSpacing.chatMaxWidth,
          ),
          child: GrokkerPanel(
            padding: const EdgeInsets.all(GrokkerSpacing.s16),
            radius: GrokkerRadius.card,
            color: GrokkerColors.errorRedMuted.withValues(alpha: 0.25),
            accentStrip: true,
            accentColor: GrokkerColors.errorRed,
            border: BorderSide(
              color: GrokkerColors.errorRed.withValues(alpha: 0.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: GrokkerColors.errorRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          GrokkerRadius.input,
                        ),
                        border: Border.all(
                          color: GrokkerColors.errorRed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: GrokkerColors.errorRed,
                      ),
                    ),
                    const SizedBox(width: GrokkerSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const GrokkerBadge(
                            label: 'Error',
                            variant: GrokkerBadgeVariant.error,
                            icon: Icons.error_outline,
                          ),
                          const SizedBox(height: GrokkerSpacing.s4),
                          Text(
                            widget.error.title,
                            style: GrokkerTypography.label(
                              color: theme.headingText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: GrokkerSpacing.s12),
                Text(
                  widget.error.message,
                  style: GrokkerTypography.bodySm(color: GrokkerColors.cloud),
                ),
                const SizedBox(height: GrokkerSpacing.s8),
                Container(
                  padding: const EdgeInsets.all(GrokkerSpacing.s12),
                  decoration: BoxDecoration(
                    color: GrokkerSurfaces.voidFloor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(GrokkerRadius.input),
                    border: Border.all(color: GrokkerColors.gunmetal),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 14,
                        color: GrokkerColors.warningAmber,
                      ),
                      const SizedBox(width: GrokkerSpacing.s8),
                      Expanded(
                        child: Text(
                          widget.error.suggestedFix,
                          style: GrokkerTypography.caption(
                            color: theme.subtleText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.error.technicalDetails != null) ...[
                  const SizedBox(height: GrokkerSpacing.s8),
                  GrokkerGhostButton(
                    label: _expanded
                        ? 'Hide details'
                        : 'Show technical details',
                    icon: _expanded ? Icons.expand_less : Icons.expand_more,
                    accent: true,
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                  if (_expanded)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(top: GrokkerSpacing.s8),
                      padding: const EdgeInsets.all(GrokkerSpacing.s12),
                      decoration: BoxDecoration(
                        color: GrokkerSurfaces.voidFloor,
                        borderRadius: BorderRadius.circular(
                          GrokkerRadius.input,
                        ),
                        border: Border.all(color: GrokkerColors.gunmetal),
                      ),
                      child: SelectableText(
                        widget.error.technicalDetails!,
                        style: GrokkerTypography.mono(size: 11),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
