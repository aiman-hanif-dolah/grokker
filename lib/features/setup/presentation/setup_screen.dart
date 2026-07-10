import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../styles/design_tokens.dart';
import '../../../styles/grokker_components.dart';
import '../../../styles/grokker_typography.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrokkerSurfaces.voidFloor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GrokkerSpacing.s48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GrokkerBadge(
                  label: 'Setup required',
                  variant: GrokkerBadgeVariant.info,
                ),
                const SizedBox(height: GrokkerSpacing.s24),
                Text('Grok CLI not found.', style: GrokkerTypography.display()),
                const SizedBox(height: GrokkerSpacing.s16),
                Text(
                  'Grokker uses your local Grok Build CLI. Your SuperGrok login stays managed by xAI.',
                  style: GrokkerTypography.subheading(),
                ),
                const SizedBox(height: GrokkerSpacing.s24),
                Text(
                  'Install Grok Build CLI, authenticate in your terminal, then restart Grokker.',
                  style: GrokkerTypography.body(),
                ),
                const SizedBox(height: GrokkerSpacing.s12),
                Text(
                  'If grok works in Terminal but Grokker cannot find it, set the CLI path in '
                  'Settings to ~/.grok/bin/grok. macOS apps do not inherit your shell PATH.',
                  style: GrokkerTypography.bodySm(color: GrokkerColors.ash),
                ),
                const SizedBox(height: GrokkerSpacing.s8),
                Text(
                  'If you installed Homebrew\'s unrelated "grok" log tool, Grokker will ignore it. '
                  'Use the official xAI Grok Build CLI at ~/.grok/bin/grok.',
                  style: GrokkerTypography.bodySm(color: GrokkerColors.ash),
                ),
                const SizedBox(height: GrokkerSpacing.s32),
                _InstallBlock(
                  title: 'macOS',
                  commands: const [
                    'npm install -g @xai-official/grok',
                    'grok /login',
                    'grok --version',
                  ],
                ),
                const SizedBox(height: GrokkerSpacing.s24),
                _InstallBlock(
                  title: 'Windows',
                  commands: const [
                    'npm install -g @xai-official/grok',
                    'grok /login',
                    'grok --version',
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: GrokkerSpacing.s24),
                  GrokkerPanel(
                    padding: const EdgeInsets.all(GrokkerSpacing.s16),
                    radius: GrokkerRadius.chip,
                    color: GrokkerSurfaces.raised,
                    border: const BorderSide(color: GrokkerColors.pewter),
                    child: SelectableText(
                      'Details: $error',
                      style: GrokkerTypography.mono(size: 12),
                    ),
                  ),
                ],
                const SizedBox(height: GrokkerSpacing.s32),
                GrokkerPrimaryButton(
                  label: 'Retry detection',
                  icon: Icons.refresh,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InstallBlock extends StatelessWidget {
  const _InstallBlock({required this.title, required this.commands});

  final String title;
  final List<String> commands;

  @override
  Widget build(BuildContext context) {
    return GrokkerPanel(
      padding: const EdgeInsets.all(GrokkerSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GrokkerEyebrow(title),
          const SizedBox(height: GrokkerSpacing.s16),
          ...commands.map((cmd) => _CommandRow(command: cmd)),
        ],
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({required this.command});

  final String command;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GrokkerSpacing.s8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: GrokkerSpacing.s12,
                vertical: GrokkerSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: GrokkerSurfaces.voidFloor,
                borderRadius: BorderRadius.circular(GrokkerRadius.input),
                border: Border.all(color: GrokkerColors.gunmetal),
              ),
              child: Text(command, style: GrokkerTypography.mono(size: 13)),
            ),
          ),
          GrokkerIconFrameButton(
            icon: Icons.copy_outlined,
            tooltip: 'Copy',
            onPressed: () => Clipboard.setData(ClipboardData(text: command)),
          ),
        ],
      ),
    );
  }
}
