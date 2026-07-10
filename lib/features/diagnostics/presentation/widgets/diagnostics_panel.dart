import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../styles/design_tokens.dart';
import '../../../../styles/grokker_components.dart';
import '../../../../styles/grokker_typography.dart';
import '../cubit/diagnostics_cubit.dart';

class DiagnosticsPanel extends StatelessWidget {
  const DiagnosticsPanel({
    super.key,
    required this.state,
    required this.onRestart,
    required this.onClose,
  });

  final DiagnosticsState state;
  final VoidCallback onRestart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (!state.visible) return const SizedBox.shrink();

    return Container(
      height: 280,
      decoration: const BoxDecoration(
        color: GrokkerSurfaces.deepPanel,
        border: Border(top: BorderSide(color: GrokkerColors.gunmetal)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: GrokkerSpacing.s24,
              vertical: GrokkerSpacing.s12,
            ),
            child: Row(
              children: [
                Text(
                  'Diagnostics',
                  style: GrokkerTypography.label(color: GrokkerColors.white),
                ),
                const Spacer(),
                GrokkerGhostButton(
                  label: 'Copy',
                  icon: Icons.copy_outlined,
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: state.toClipboardText()),
                  ),
                ),
                GrokkerGhostButton(
                  label: 'Restart Grok',
                  icon: Icons.restart_alt,
                  onPressed: onRestart,
                ),
                GrokkerIconFrameButton(icon: Icons.close, onPressed: onClose),
              ],
            ),
          ),
          const GrokkerSurfaceDivider(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _LogList(
                    title: 'ACP events (last ${state.acpEvents.length})',
                    lines: state.acpEvents.map((e) => e.toString()).toList(),
                  ),
                ),
                const GrokkerSurfaceDivider(vertical: true),
                Expanded(
                  child: _LogList(
                    title: 'stderr (last ${state.stderrLines.length})',
                    lines: state.stderrLines,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GrokkerSpacing.s24,
            vertical: GrokkerSpacing.s8,
          ),
          child: GrokkerEyebrow(title),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(GrokkerSpacing.s16),
            itemCount: lines.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: GrokkerSpacing.s4),
              child: SelectableText(
                lines[i],
                style: GrokkerTypography.mono(size: 11),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
