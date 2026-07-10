import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../shared/models/app_settings.dart';
import '../../../../shared/models/approval_mode.dart';
import '../../../../shared/models/attachment_item.dart';
import '../../../../shared/models/diff_file.dart';
import '../../../../shared/models/grok_model.dart';
import '../../../../shared/models/thinking_effort.dart';
import '../../../../shared/models/workspace_info.dart';
import '../../../../styles/design_tokens.dart';
import '../../../../styles/grokker_components.dart';
import '../../../../styles/grokker_typography.dart';
import '../../../acp/data/services/grok_cli_locator_service.dart';
import '../../../acp/domain/models/acp_models.dart';
import '../../../goal/presentation/cubit/goal_cubit.dart';
import '../../../multitask/presentation/cubit/multitask_cubit.dart';
import '../../presentation/cubit/diagnostics_cubit.dart';

/// Always-on control rail: session controls + every app setting (no separate
/// settings screen).
class InspectorPanel extends StatelessWidget {
  const InspectorPanel({
    super.key,
    required this.visible,
    required this.workspace,
    required this.model,
    required this.availableModels,
    required this.effort,
    required this.settings,
    required this.attachments,
    required this.acpSessionId,
    required this.diffs,
    required this.selectedDiff,
    required this.pendingPermission,
    required this.diagnostics,
    required this.processStatus,
    required this.initialized,
    required this.grokVersion,
    required this.grokPath,
    required this.lastError,
    required this.onModelChanged,
    required this.onEffortChanged,
    required this.onSettingsChanged,
    required this.onSelectDiff,
    required this.onApprovePermission,
    required this.onDenyPermission,
    required this.onCopyDiff,
    required this.onToggleDiagnostics,
    required this.onResetSettings,
    this.onCollapse,
    this.goalState = const GoalState(),
    this.multitaskState = const MultitaskState(),
    this.onStopGoal,
    this.onToggleMultitask,
    this.onToggleSubagents,
    this.onQueueMultitaskFromText,
    this.onClearMultitaskQueue,
    this.onRunMultitaskQueue,
  });

  final bool visible;
  final WorkspaceInfo? workspace;
  final GrokModel model;

  /// Live models from Grok CLI cache (not a hardcoded enum).
  final List<GrokModel> availableModels;
  final ThinkingEffort effort;
  final AppSettings settings;
  final GoalState goalState;
  final MultitaskState multitaskState;
  final VoidCallback? onStopGoal;
  final VoidCallback? onToggleMultitask;
  final ValueChanged<bool>? onToggleSubagents;
  final ValueChanged<String>? onQueueMultitaskFromText;
  final VoidCallback? onClearMultitaskQueue;
  final VoidCallback? onRunMultitaskQueue;
  final List<AttachmentItem> attachments;
  final String? acpSessionId;
  final List<DiffFile> diffs;
  final DiffFile? selectedDiff;
  final PendingPermissionRequest? pendingPermission;
  final DiagnosticsState diagnostics;
  final String processStatus;
  final bool initialized;
  final String? grokVersion;
  final String? grokPath;
  final String? lastError;
  final ValueChanged<GrokModel> onModelChanged;
  final ValueChanged<ThinkingEffort> onEffortChanged;
  final ValueChanged<AppSettings> onSettingsChanged;
  final ValueChanged<String> onSelectDiff;
  final VoidCallback onApprovePermission;
  final VoidCallback onDenyPermission;
  final VoidCallback onCopyDiff;
  final VoidCallback onToggleDiagnostics;
  final VoidCallback onResetSettings;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final theme = GrokkerThemeExtension.of(context);
    return Container(
      width: GrokkerSpacing.inspectorWidth,
      decoration: BoxDecoration(
        color: theme.panel,
        border: Border(left: BorderSide(color: theme.panelBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(onCollapse: onCollapse),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              children: [
                // ── Session (always visible) ──────────────────────────
                _Card(
                  icon: Icons.psychology_outlined,
                  title: 'Model',
                  child: _Dropdown<GrokModel>(
                    value: _resolveModel(model, availableModels),
                    items: _modelItems(availableModels),
                    onChanged: (v) {
                      if (v != null) onModelChanged(v);
                    },
                  ),
                ),
                _Card(
                  icon: Icons.bolt_outlined,
                  title: 'Effort',
                  child: _Dropdown<ThinkingEffort>(
                    value: effort,
                    items: ThinkingEffort.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e.displayName,
                              style: GrokkerTypography.bodySm(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onEffortChanged(v);
                    },
                  ),
                ),

                if (pendingPermission != null)
                  _Card(
                    icon: Icons.shield_outlined,
                    title: 'Approval needed',
                    accent: GrokkerColors.warningAmber,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pendingPermission!.title,
                          style: GrokkerTypography.label(
                            color: GrokkerColors.snow,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pendingPermission!.description,
                          style: GrokkerTypography.bodySm(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GrokkerPrimaryButton(
                                label: 'Approve',
                                dense: true,
                                onPressed: onApprovePermission,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GrokkerOutlinedButton(
                                label: 'Deny',
                                dense: true,
                                onPressed: onDenyPermission,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // ── Goal & Multitask ──────────────────────────────────
                _SectionLabel('Goal & Multitask'),
                _Card(
                  icon: Icons.flag_outlined,
                  title: 'Goal mode',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goalState.isActive
                            ? 'Active · iteration ${goalState.iteration}/${goalState.maxIterations}'
                            : goalState.isComplete
                            ? 'Completed'
                            : 'Off — toggle Goal under the prompt',
                        style: GrokkerTypography.bodySm(
                          color: goalState.isActive
                              ? GrokkerColors.emberBright
                              : GrokkerColors.ash,
                        ),
                      ),
                      if (goalState.text != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          goalState.text!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GrokkerTypography.caption(
                            color: GrokkerColors.fog,
                          ),
                        ),
                      ],
                      if (goalState.lastStatus != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          goalState.lastStatus!,
                          style: GrokkerTypography.caption(
                            color: GrokkerColors.fog,
                          ),
                        ),
                      ],
                      if (goalState.isActive && onStopGoal != null) ...[
                        const SizedBox(height: 8),
                        GrokkerOutlinedButton(
                          key: const ValueKey('stop_goal'),
                          label: 'Stop goal',
                          dense: true,
                          expanded: true,
                          onPressed: onStopGoal,
                        ),
                      ],
                    ],
                  ),
                ),
                _Card(
                  icon: Icons.hub_outlined,
                  title: 'Multitask',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cannot run with Goal mode — turning one on disables the other.',
                        style: GrokkerTypography.caption(
                          color: GrokkerColors.fog,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _SwitchRow(
                        label: goalState.isActive
                            ? 'Enabled (off while Goal runs)'
                            : 'Enabled (parallel / subagents)',
                        value: multitaskState.enabled,
                        onChanged: goalState.isActive
                            ? null
                            : (v) {
                                if (onToggleMultitask != null &&
                                    v != multitaskState.enabled) {
                                  onToggleMultitask!();
                                }
                              },
                      ),
                      _SwitchRow(
                        label: 'Prefer spawn_subagent',
                        value: multitaskState.useSubagents,
                        dense: true,
                        onChanged: multitaskState.enabled
                            ? (v) => onToggleSubagents?.call(v)
                            : null,
                      ),
                      if (onQueueMultitaskFromText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Queue: paste tasks separated by blank lines or ---',
                          style: GrokkerTypography.caption(
                            color: GrokkerColors.fog,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _QueueField(onSubmit: onQueueMultitaskFromText!),
                      ],
                      if (multitaskState.queue.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...multitaskState.queue
                            .take(8)
                            .map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• [${t.status.name}] ${t.prompt}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GrokkerTypography.caption(
                                    color: GrokkerColors.ash,
                                  ),
                                ),
                              ),
                            ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (onRunMultitaskQueue != null)
                              Expanded(
                                child: GrokkerPrimaryButton(
                                  label: 'Run queue',
                                  dense: true,
                                  onPressed: onRunMultitaskQueue,
                                ),
                              ),
                            if (onClearMultitaskQueue != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: GrokkerOutlinedButton(
                                  label: 'Clear',
                                  dense: true,
                                  onPressed: onClearMultitaskQueue,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Defaults ──────────────────────────────────────────
                _SectionLabel('Defaults'),
                _Card(
                  icon: Icons.tune_rounded,
                  title: 'Default model',
                  child: _Dropdown<GrokModel>(
                    value: _resolveModel(
                      settings.defaultModel,
                      availableModels,
                    ),
                    items: _modelItems(availableModels),
                    onChanged: (v) {
                      if (v != null) {
                        onSettingsChanged(settings.copyWith(defaultModel: v));
                      }
                    },
                  ),
                ),
                _Card(
                  icon: Icons.speed_outlined,
                  title: 'Default effort',
                  child: _Dropdown<ThinkingEffort>(
                    value: settings.defaultEffort,
                    items: ThinkingEffort.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e.displayName,
                              style: GrokkerTypography.bodySm(),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        onSettingsChanged(settings.copyWith(defaultEffort: v));
                      }
                    },
                  ),
                ),
                _Card(
                  icon: Icons.verified_user_outlined,
                  title: 'Approval mode',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Dropdown<ApprovalMode>(
                        value: settings.approvalMode,
                        items: ApprovalMode.values
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  m.displayName,
                                  style: GrokkerTypography.bodySm(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            onSettingsChanged(
                              settings.copyWith(approvalMode: v),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        settings.approvalMode.description,
                        style: GrokkerTypography.caption(
                          color: GrokkerColors.fog,
                        ),
                      ),
                    ],
                  ),
                ),
                _Card(
                  icon: Icons.keyboard_return,
                  title: 'Enter key',
                  child: _Dropdown<ComposerEnterBehavior>(
                    value: settings.composerEnterBehavior,
                    items: ComposerEnterBehavior.values
                        .map(
                          (b) => DropdownMenuItem(
                            value: b,
                            child: Text(switch (b) {
                              ComposerEnterBehavior.send => 'Send prompt',
                              ComposerEnterBehavior.newline => 'Insert newline',
                            }, style: GrokkerTypography.bodySm()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        onSettingsChanged(
                          settings.copyWith(composerEnterBehavior: v),
                        );
                      }
                    },
                  ),
                ),
                _Card(
                  icon: Icons.palette_outlined,
                  title: 'Theme',
                  child: _Dropdown<AppThemeMode>(
                    value: settings.themeMode,
                    items: [
                      DropdownMenuItem(
                        value: AppThemeMode.dark,
                        child: Text(
                          'Dark (default)',
                          style: GrokkerTypography.bodySm(),
                        ),
                      ),
                      DropdownMenuItem(
                        value: AppThemeMode.light,
                        child: Text('Light', style: GrokkerTypography.bodySm()),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        onSettingsChanged(settings.copyWith(themeMode: v));
                      }
                    },
                  ),
                ),

                // ── Grok CLI ──────────────────────────────────────────
                _SectionLabel('Grok CLI'),
                _Card(
                  icon: Icons.terminal,
                  title: 'CLI path',
                  child: _PathField(
                    initial: settings.grokCommandPath,
                    hint: 'empty = auto-detect',
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(grokCommandPath: v),
                    ),
                  ),
                ),
                _SwitchRow(
                  label: 'Use npx @xai-official/grok',
                  value: settings.useNpxGrok,
                  onChanged: (v) =>
                      onSettingsChanged(settings.copyWith(useNpxGrok: v)),
                ),

                // ── Behavior ──────────────────────────────────────────
                _SectionLabel('Behavior'),
                _SwitchRow(
                  label: 'Auto-start Grok on launch',
                  value: settings.autoStartGrokProcess,
                  onChanged: (v) => onSettingsChanged(
                    settings.copyWith(autoStartGrokProcess: v),
                  ),
                ),
                _SwitchRow(
                  label: 'Auto-create session',
                  value: settings.autoCreateSession,
                  onChanged: (v) => onSettingsChanged(
                    settings.copyWith(autoCreateSession: v),
                  ),
                ),
                _SwitchRow(
                  label: 'Inline small text attachments',
                  value: settings.inlineSmallTextAttachments,
                  onChanged: (v) => onSettingsChanged(
                    settings.copyWith(inlineSmallTextAttachments: v),
                  ),
                ),
                _SwitchRow(
                  label: 'Show raw ACP events',
                  value: settings.showRawAcpEvents,
                  onChanged: (v) =>
                      onSettingsChanged(settings.copyWith(showRawAcpEvents: v)),
                ),
                _SwitchRow(
                  label: 'Show stderr logs',
                  value: settings.showStderrLogs,
                  onChanged: (v) =>
                      onSettingsChanged(settings.copyWith(showStderrLogs: v)),
                ),
                _SwitchRow(
                  label: 'Privacy mode',
                  value: settings.privacyMode,
                  onChanged: (v) =>
                      onSettingsChanged(settings.copyWith(privacyMode: v)),
                ),

                // ── Tools ─────────────────────────────────────────────
                _SectionLabel('Hidden tools'),
                _Card(
                  icon: Icons.build_outlined,
                  title: 'Filter tool lines',
                  child: Column(
                    children: [
                      for (final tool in const [
                        'grep',
                        'read_file',
                        'run_terminal_command',
                        'web_search',
                      ])
                        _SwitchRow(
                          label: tool,
                          value: settings.hiddenTools.contains(tool),
                          dense: true,
                          onChanged: (hidden) {
                            final updated = Set<String>.from(
                              settings.hiddenTools,
                            );
                            if (hidden) {
                              updated.add(tool);
                            } else {
                              updated.remove(tool);
                            }
                            onSettingsChanged(
                              settings.copyWith(hiddenTools: updated),
                            );
                          },
                        ),
                    ],
                  ),
                ),

                // ── Workspace / ACP ───────────────────────────────────
                _SectionLabel('Session info'),
                _Card(
                  icon: Icons.folder_outlined,
                  title: 'Workspace',
                  child: workspace != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workspace!.name,
                              style: GrokkerTypography.label(
                                color: GrokkerColors.snow,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _MonoBox(workspace!.path),
                            if (workspace!.primaryProjectType.isNotEmpty ||
                                workspace!.gitBranch != null) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (workspace!.primaryProjectType.isNotEmpty)
                                    GrokkerMetaChip(
                                      label: workspace!.primaryProjectType,
                                      icon: Icons.code_rounded,
                                      color: GrokkerColors.emberBright,
                                    ),
                                  if (workspace!.gitBranch != null)
                                    GrokkerMetaChip(
                                      label: workspace!.gitBranch!,
                                      icon: Icons.account_tree_outlined,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        )
                      : Text(
                          'No workspace',
                          style: GrokkerTypography.bodySm(
                            color: GrokkerColors.fog,
                          ),
                        ),
                ),
                _Card(
                  icon: Icons.link_outlined,
                  title: 'ACP session',
                  child: _MonoBox(acpSessionId ?? 'not created yet'),
                ),
                _Card(
                  icon: Icons.attach_file_outlined,
                  title: 'Attachments',
                  trailing: attachments.isNotEmpty
                      ? GrokkerMetaChip(label: '${attachments.length}')
                      : null,
                  child: attachments.isEmpty
                      ? Text(
                          'None — paste or drop onto terminal',
                          style: GrokkerTypography.bodySm(
                            color: GrokkerColors.fog,
                          ),
                        )
                      : Column(
                          children: attachments
                              .map(
                                (a) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _attachmentIcon(a.type),
                                        size: 14,
                                        color: GrokkerColors.emberBright,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          a.fileName,
                                          style: GrokkerTypography.bodySm(),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),

                // ── Diffs ─────────────────────────────────────────────
                _Card(
                  icon: Icons.difference_outlined,
                  title: 'File changes',
                  trailing: diffs.isNotEmpty
                      ? GrokkerMetaChip(label: '${diffs.length}')
                      : null,
                  child: diffs.isEmpty
                      ? Text(
                          'No changes yet',
                          style: GrokkerTypography.bodySm(
                            color: GrokkerColors.fog,
                          ),
                        )
                      : Column(
                          children: [
                            _Dropdown<String>(
                              value: selectedDiff?.id,
                              hint: 'Select file',
                              items: diffs
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d.id,
                                      child: Text(
                                        d.path,
                                        overflow: TextOverflow.ellipsis,
                                        style: GrokkerTypography.bodySm(),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) onSelectDiff(v);
                              },
                            ),
                            if (selectedDiff != null) ...[
                              const SizedBox(height: 8),
                              GrokkerBadge(
                                label:
                                    selectedDiff!.status == DiffStatus.applied
                                    ? 'Applied'
                                    : 'Pending',
                                variant:
                                    selectedDiff!.status == DiffStatus.applied
                                    ? GrokkerBadgeVariant.success
                                    : GrokkerBadgeVariant.info,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 160,
                                ),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: GrokkerSurfaces.voidFloor,
                                  borderRadius: BorderRadius.circular(
                                    GrokkerRadius.input,
                                  ),
                                  border: Border.all(color: GrokkerColors.iron),
                                ),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    selectedDiff!.unifiedDiff,
                                    style: GrokkerTypography.mono(size: 10),
                                  ),
                                ),
                              ),
                              GrokkerGhostButton(
                                label: 'Copy diff',
                                icon: Icons.copy_outlined,
                                accent: true,
                                onPressed: onCopyDiff,
                              ),
                            ],
                          ],
                        ),
                ),

                // ── Diagnostics ───────────────────────────────────────
                _SectionLabel('Runtime'),
                _Card(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Grok process',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          GrokkerMetaChip(
                            label: grokVersion ?? 'unknown',
                            icon: Icons.terminal,
                          ),
                          GrokkerMetaChip(
                            label: processStatus,
                            icon: Icons.memory_outlined,
                            color: GrokkerColors.emberBright,
                          ),
                          GrokkerMetaChip(
                            label: initialized ? 'ACP ready' : 'ACP pending',
                            icon: Icons.check_circle_outline,
                            color: initialized
                                ? GrokkerColors.mapGreen
                                : GrokkerColors.fog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _MonoBox(
                        grokPath ??
                            GrokCliLocatorService.officialGrokPath() ??
                            '',
                      ),
                      if (lastError != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: GrokkerColors.errorRed.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(
                              GrokkerRadius.input,
                            ),
                            border: Border.all(
                              color: GrokkerColors.errorRed.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          child: Text(
                            lastError!,
                            style: GrokkerTypography.caption(
                              color: GrokkerColors.errorRed,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      GrokkerOutlinedButton(
                        label: 'Full diagnostics',
                        icon: Icons.bug_report_outlined,
                        dense: true,
                        expanded: true,
                        onPressed: onToggleDiagnostics,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                GrokkerGhostButton(
                  label: 'Reset all settings',
                  icon: Icons.restart_alt,
                  onPressed: onResetSettings,
                ),
                const SizedBox(height: 8),
                Text(
                  'Changes save immediately. No separate settings screen.',
                  style: GrokkerTypography.caption(color: GrokkerColors.fog),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _attachmentIcon(AttachmentType type) {
    switch (type) {
      case AttachmentType.pdf:
        return Icons.picture_as_pdf;
      case AttachmentType.markdown:
        return Icons.description;
      case AttachmentType.code:
        return Icons.code;
      case AttachmentType.image:
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file;
    }
  }

  static List<DropdownMenuItem<GrokModel>> _modelItems(List<GrokModel> models) {
    final list = models.isEmpty
        ? const [GrokModel.grok45, GrokModel.composer25Fast]
        : models;
    return list
        .map(
          (m) => DropdownMenuItem(
            value: m,
            child: Text(
              m.isDefault ? '${m.displayName} (default)' : m.displayName,
              style: GrokkerTypography.bodySm(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
  }

  static GrokModel _resolveModel(GrokModel current, List<GrokModel> models) {
    for (final m in models) {
      if (m.id == current.id) return m;
    }
    if (models.isNotEmpty) return models.first;
    return current;
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onCollapse});

  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: GrokkerColors.ember.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(GrokkerRadius.input),
              border: Border.all(
                color: GrokkerColors.ember.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.tune_rounded,
              size: 16,
              color: GrokkerColors.emberBright,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Controls',
                  style: GrokkerTypography.label(color: GrokkerColors.snow),
                ),
                Text(
                  'all settings live here',
                  style: GrokkerTypography.caption(color: GrokkerColors.fog),
                ),
              ],
            ),
          ),
          if (onCollapse != null)
            IconButton(
              tooltip: 'Hide panel (Ctrl+Shift+I)',
              onPressed: onCollapse,
              icon: const Icon(Icons.chevron_right, size: 18),
              color: GrokkerColors.fog,
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: GrokkerEyebrow(text),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.accent = GrokkerColors.ember,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = GrokkerThemeExtension.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.canvas,
          borderRadius: BorderRadius.circular(GrokkerRadius.card),
          border: Border.all(color: theme.panelBorder),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: GrokkerColors.fog),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: GrokkerTypography.caption(color: GrokkerColors.fog),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GrokkerSurfaces.raised,
        borderRadius: BorderRadius.circular(GrokkerRadius.input),
        border: Border.all(color: GrokkerColors.iron),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: hint != null
              ? Text(
                  hint!,
                  style: GrokkerTypography.bodySm(color: GrokkerColors.fog),
                )
              : null,
          dropdownColor: GrokkerSurfaces.raised,
          borderRadius: BorderRadius.circular(GrokkerRadius.chip),
          icon: const Icon(
            Icons.expand_more,
            color: GrokkerColors.fog,
            size: 18,
          ),
          style: GrokkerTypography.bodySm(color: GrokkerColors.mist),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 2 : 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GrokkerTypography.bodySm(
                color: onChanged == null
                    ? GrokkerColors.fog
                    : GrokkerColors.mist,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class _PathField extends StatefulWidget {
  const _PathField({required this.initial, required this.onChanged, this.hint});

  final String initial;
  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  State<_PathField> createState() => _PathFieldState();
}

class _PathFieldState extends State<_PathField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void didUpdateWidget(covariant _PathField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial &&
        widget.initial != _controller.text) {
      _controller.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: GrokkerTypography.mono(size: 12, color: GrokkerColors.mist),
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        hintStyle: GrokkerTypography.mono(size: 12, color: GrokkerColors.fog),
        filled: true,
        fillColor: GrokkerSurfaces.raised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.input),
          borderSide: const BorderSide(color: GrokkerColors.iron),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.input),
          borderSide: const BorderSide(color: GrokkerColors.iron),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrokkerRadius.input),
          borderSide: const BorderSide(color: GrokkerColors.ember, width: 1.5),
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _MonoBox extends StatelessWidget {
  const _MonoBox(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: GrokkerSurfaces.raised,
        borderRadius: BorderRadius.circular(GrokkerRadius.input),
        border: Border.all(color: GrokkerColors.iron),
      ),
      child: SelectableText(
        text,
        style: GrokkerTypography.mono(size: 11, color: GrokkerColors.ash),
      ),
    );
  }
}

class _QueueField extends StatefulWidget {
  const _QueueField({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_QueueField> createState() => _QueueFieldState();
}

class _QueueFieldState extends State<_QueueField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          maxLines: 3,
          minLines: 2,
          style: GrokkerTypography.mono(size: 11, color: GrokkerColors.mist),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'task one\n---\ntask two',
            hintStyle: GrokkerTypography.mono(
              size: 11,
              color: GrokkerColors.fog,
            ),
            filled: true,
            fillColor: GrokkerSurfaces.raised,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GrokkerRadius.input),
              borderSide: const BorderSide(color: GrokkerColors.iron),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GrokkerRadius.input),
              borderSide: const BorderSide(color: GrokkerColors.iron),
            ),
          ),
        ),
        const SizedBox(height: 6),
        GrokkerOutlinedButton(
          label: 'Add to queue',
          dense: true,
          expanded: true,
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;
            widget.onSubmit(text);
            _controller.clear();
          },
        ),
      ],
    );
  }
}
