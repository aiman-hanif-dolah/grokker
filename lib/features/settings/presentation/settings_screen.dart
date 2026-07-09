import 'package:flutter/material.dart';

import '../../../shared/models/app_settings.dart';
import '../../../shared/models/approval_mode.dart';
import '../../../shared/models/grok_model.dart';
import '../../../shared/models/thinking_effort.dart';
import '../../../styles/design_tokens.dart';
import '../../../styles/grokker_components.dart';
import '../../../styles/grokker_typography.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onSave,
    required this.onReset,
    required this.onClearCache,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onSave;
  final VoidCallback onReset;
  final VoidCallback onClearCache;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrokkerSurfaces.voidFloor,
      appBar: AppBar(
        title: Text('Settings', style: GrokkerTypography.label(color: GrokkerColors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(GrokkerSpacing.s24),
        children: [
          GrokkerSection(
            title: 'Grok CLI',
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Grok CLI command path',
                  ),
                  controller: TextEditingController(text: _settings.grokCommandPath),
                  onChanged: (v) =>
                      _settings = _settings.copyWith(grokCommandPath: v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Use npx @xai-official/grok', style: GrokkerTypography.bodySm()),
                  value: _settings.useNpxGrok,
                  onChanged: (v) =>
                      setState(() => _settings = _settings.copyWith(useNpxGrok: v)),
                ),
              ],
            ),
          ),
          GrokkerSection(
            title: 'Defaults',
            child: Column(
              children: [
                _dropdown<GrokModel>(
                  'Default model',
                  _settings.defaultModel,
                  GrokModel.values,
                  (m) => m.displayName,
                  (v) => setState(() => _settings = _settings.copyWith(defaultModel: v)),
                ),
                _dropdown<ThinkingEffort>(
                  'Default thinking effort',
                  _settings.defaultEffort,
                  ThinkingEffort.values,
                  (e) => e.displayName,
                  (v) => setState(() => _settings = _settings.copyWith(defaultEffort: v)),
                ),
                _dropdown<ApprovalMode>(
                  'Approval mode',
                  _settings.approvalMode,
                  ApprovalMode.values,
                  (m) => m.displayName,
                  (v) => setState(() => _settings = _settings.copyWith(approvalMode: v)),
                ),
                if (_settings.approvalMode == ApprovalMode.fullTrust)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: GrokkerSpacing.s8),
                    child: Text(
                      'Full trust mode allows Grok to modify local files without approval.',
                      style: GrokkerTypography.caption(color: GrokkerColors.ash),
                    ),
                  ),
                _dropdown<AppThemeMode>(
                  'Theme',
                  _settings.themeMode,
                  AppThemeMode.values,
                  (t) => t.name,
                  (v) => setState(() => _settings = _settings.copyWith(themeMode: v)),
                ),
                _dropdown<ComposerEnterBehavior>(
                  'Enter key behavior',
                  _settings.composerEnterBehavior,
                  ComposerEnterBehavior.values,
                  (b) => switch (b) {
                    ComposerEnterBehavior.send => 'Send',
                    ComposerEnterBehavior.newline => 'Newline',
                  },
                  (v) => setState(
                    () => _settings = _settings.copyWith(composerEnterBehavior: v),
                  ),
                ),
              ],
            ),
          ),
          GrokkerSection(
            title: 'Behavior',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Auto-start Grok process on launch', style: GrokkerTypography.bodySm()),
                  value: _settings.autoStartGrokProcess,
                  onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(autoStartGrokProcess: v),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Auto-create session after opening workspace', style: GrokkerTypography.bodySm()),
                  value: _settings.autoCreateSession,
                  onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(autoCreateSession: v),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Show raw ACP events', style: GrokkerTypography.bodySm()),
                  value: _settings.showRawAcpEvents,
                  onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(showRawAcpEvents: v),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Show stderr logs', style: GrokkerTypography.bodySm()),
                  value: _settings.showStderrLogs,
                  onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(showStderrLogs: v),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Inline small text attachments', style: GrokkerTypography.bodySm()),
                  value: _settings.inlineSmallTextAttachments,
                  onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(inlineSmallTextAttachments: v),
                  ),
                ),
              ],
            ),
          ),
          GrokkerSection(
            title: 'Privacy',
            child: Text(
              'Grokker communicates with Grok through the official Grok Build CLI. '
              'Authentication and remote model access are handled by xAI\'s CLI, not by Grokker.',
              style: GrokkerTypography.bodySm(),
            ),
          ),
          GrokkerSection(
            title: 'Tools',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hidden tools are filtered from the chat view.',
                  style: GrokkerTypography.caption(color: GrokkerColors.ash),
                ),
                const SizedBox(height: GrokkerSpacing.s12),
                _ToolToggle(
                  name: 'grep',
                  isHidden: _settings.hiddenTools.contains('grep'),
                  onChanged: (hidden) => setState(() {
                    final updated = Set<String>.from(_settings.hiddenTools);
                    if (hidden) {
                      updated.add('grep');
                    } else {
                      updated.remove('grep');
                    }
                    _settings = _settings.copyWith(hiddenTools: updated);
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: GrokkerSpacing.s24),
          Wrap(
            spacing: GrokkerSpacing.s12,
            runSpacing: GrokkerSpacing.s12,
            children: [
              GrokkerPrimaryButton(
                label: 'Save',
                onPressed: () => widget.onSave(_settings),
              ),
              GrokkerOutlinedButton(
                label: 'Reset settings',
                onPressed: widget.onReset,
              ),
              GrokkerOutlinedButton(
                label: 'Clear cache',
                onPressed: widget.onClearCache,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>(
    String label,
    T value,
    List<T> items,
    String Function(T) labelFn,
    ValueChanged<T> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GrokkerSpacing.s8),
      child: DropdownButtonFormField<T>(
        decoration: InputDecoration(labelText: label),
        initialValue: value,
        dropdownColor: GrokkerSurfaces.overlay,
        items: items
            .map((i) => DropdownMenuItem(
                  value: i,
                  child: Text(labelFn(i), style: GrokkerTypography.bodySm()),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _ToolToggle extends StatelessWidget {
  const _ToolToggle({
    required this.name,
    required this.isHidden,
    required this.onChanged,
  });

  final String name;
  final bool isHidden;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        name,
        style: GrokkerTypography.bodySm(),
      ),
      subtitle: Text(
        isHidden ? 'Hidden from chat' : 'Visible in chat',
        style: GrokkerTypography.caption(color: GrokkerColors.ash),
      ),
      value: isHidden,
      onChanged: onChanged,
    );
  }
}