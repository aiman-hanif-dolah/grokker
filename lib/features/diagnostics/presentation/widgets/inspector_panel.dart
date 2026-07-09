import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
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
import '../../presentation/cubit/diagnostics_cubit.dart';

class InspectorPanel extends StatelessWidget {
  const InspectorPanel({
    super.key,
    required this.visible,
    required this.workspace,
    required this.model,
    required this.effort,
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
    required this.onSelectDiff,
    required this.onApprovePermission,
    required this.onDenyPermission,
    required this.onCopyDiff,
    required this.onToggleDiagnostics,
  });

  final bool visible;
  final WorkspaceInfo? workspace;
  final GrokModel model;
  final ThinkingEffort effort;
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
  final ValueChanged<String> onSelectDiff;
  final VoidCallback onApprovePermission;
  final VoidCallback onDenyPermission;
  final VoidCallback onCopyDiff;
  final VoidCallback onToggleDiagnostics;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final theme = GrokkerThemeExtension.of(context);

    return Container(
      width: GrokkerSpacing.inspectorWidth,
      decoration: const BoxDecoration(
        color: GrokkerSurfaces.voidFloor,
        border: Border(
          left: BorderSide(color: Color(0x18FFFFFF)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              GrokkerSpacing.s20,
              GrokkerSpacing.s20,
              GrokkerSpacing.s20,
              GrokkerSpacing.s12,
            ),
            child: Row(
              children: [
                const GrokkerAvatar(
                  icon: Icons.tune_rounded,
                  color: GrokkerColors.signalBlue,
                  size: 36,
                ),
                const SizedBox(width: GrokkerSpacing.s12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inspector', style: GrokkerTypography.headingSm()),
                    Text(
                      'Session controls',
                      style: GrokkerTypography.caption(color: GrokkerColors.slate),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: GrokkerSpacing.s20),
              children: [
                _InspectorCard(
                  icon: Icons.psychology_outlined,
                  title: 'Model',
                  child: _StyledDropdown<GrokModel>(
                    value: model,
                    items: GrokModel.values
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(m.displayName, style: GrokkerTypography.bodySm()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onModelChanged(v);
                    },
                  ),
                ),
                _InspectorCard(
                  icon: Icons.bolt_outlined,
                  title: 'Thinking effort',
                  child: _StyledDropdown<ThinkingEffort>(
                    value: effort,
                    items: ThinkingEffort.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.displayName, style: GrokkerTypography.bodySm()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onEffortChanged(v);
                    },
                  ),
                ),
                _InspectorCard(
                  icon: Icons.folder_outlined,
                  title: 'Workspace',
                  child: workspace != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workspace!.name,
                              style: GrokkerTypography.label(color: theme.headingText),
                            ),
                            const SizedBox(height: GrokkerSpacing.s8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(GrokkerSpacing.s8),
                              decoration: BoxDecoration(
                                color: GrokkerSurfaces.voidFloor,
                                borderRadius: BorderRadius.circular(GrokkerRadius.input),
                                border: Border.all(color: GrokkerColors.gunmetal),
                              ),
                              child: SelectableText(
                                workspace!.path,
                                style: GrokkerTypography.mono(size: 10),
                              ),
                            ),
                            const SizedBox(height: GrokkerSpacing.s8),
                            Wrap(
                              spacing: GrokkerSpacing.s8,
                              runSpacing: GrokkerSpacing.s8,
                              children: [
                                if (workspace!.primaryProjectType.isNotEmpty)
                                  GrokkerMetaChip(
                                    label: workspace!.primaryProjectType,
                                    icon: Icons.code_rounded,
                                    color: GrokkerColors.signalBlueBright,
                                  ),
                                if (workspace!.gitBranch != null)
                                  GrokkerMetaChip(
                                    label: workspace!.gitBranch!,
                                    icon: Icons.account_tree_outlined,
                                  ),
                              ],
                            ),
                          ],
                        )
                      : Text(
                          'No workspace opened',
                          style: GrokkerTypography.bodySm(color: GrokkerColors.slate),
                        ),
                ),
                _InspectorCard(
                  icon: Icons.attach_file_outlined,
                  title: 'Attachments',
                  trailing: attachments.isNotEmpty
                      ? GrokkerMetaChip(label: '${attachments.length}')
                      : null,
                  child: attachments.isEmpty
                      ? Text('None', style: GrokkerTypography.bodySm(color: GrokkerColors.slate))
                      : Column(
                          children: attachments
                              .map(
                                (a) => Padding(
                                  padding: const EdgeInsets.only(bottom: GrokkerSpacing.s8),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(GrokkerSpacing.s8),
                                    decoration: BoxDecoration(
                                      color: GrokkerSurfaces.voidFloor,
                                      borderRadius: BorderRadius.circular(GrokkerRadius.input),
                                      border: Border.all(color: GrokkerColors.gunmetal),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _attachmentIcon(a.type),
                                          size: 14,
                                          color: GrokkerColors.signalBlueBright,
                                        ),
                                        const SizedBox(width: GrokkerSpacing.s8),
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
                                ),
                              )
                              .toList(),
                        ),
                ),
                _InspectorCard(
                  icon: Icons.link_outlined,
                  title: 'ACP session',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(GrokkerSpacing.s8),
                    decoration: BoxDecoration(
                      color: GrokkerSurfaces.voidFloor,
                      borderRadius: BorderRadius.circular(GrokkerRadius.input),
                      border: Border.all(color: GrokkerColors.gunmetal),
                    ),
                    child: SelectableText(
                      acpSessionId ?? 'Not created yet',
                      style: GrokkerTypography.mono(size: 10),
                    ),
                  ),
                ),
                if (pendingPermission != null)
                  _InspectorCard(
                    icon: Icons.shield_outlined,
                    title: 'Action approval',
                    accentColor: GrokkerColors.warningAmber,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pendingPermission!.title,
                          style: GrokkerTypography.label(color: theme.headingText),
                        ),
                        const SizedBox(height: GrokkerSpacing.s4),
                        Text(
                          pendingPermission!.description,
                          style: GrokkerTypography.bodySm(),
                        ),
                        const SizedBox(height: GrokkerSpacing.s12),
                        Row(
                          children: [
                            Expanded(
                              child: GrokkerPrimaryButton(
                                label: 'Approve',
                                dense: true,
                                onPressed: onApprovePermission,
                              ),
                            ),
                            const SizedBox(width: GrokkerSpacing.s8),
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
                _InspectorCard(
                  icon: Icons.difference_outlined,
                  title: 'File changes',
                  trailing: diffs.isNotEmpty
                      ? GrokkerMetaChip(label: '${diffs.length}')
                      : null,
                  child: diffs.isEmpty
                      ? Text('No changes yet', style: GrokkerTypography.bodySm(color: GrokkerColors.slate))
                      : Column(
                          children: [
                            _StyledDropdown<String>(
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
                              const SizedBox(height: GrokkerSpacing.s8),
                              GrokkerBadge(
                                label: selectedDiff!.status == DiffStatus.applied
                                    ? 'Applied'
                                    : 'Pending',
                                variant: selectedDiff!.status == DiffStatus.applied
                                    ? GrokkerBadgeVariant.success
                                    : GrokkerBadgeVariant.info,
                              ),
                              const SizedBox(height: GrokkerSpacing.s8),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                padding: const EdgeInsets.all(GrokkerSpacing.s12),
                                decoration: BoxDecoration(
                                  color: GrokkerSurfaces.voidFloor,
                                  borderRadius: BorderRadius.circular(GrokkerRadius.input),
                                  border: Border.all(color: GrokkerColors.gunmetal),
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
                _InspectorCard(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Diagnostics',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: GrokkerSpacing.s8,
                        runSpacing: GrokkerSpacing.s8,
                        children: [
                          GrokkerMetaChip(
                            label: grokVersion ?? 'unknown',
                            icon: Icons.terminal,
                          ),
                          GrokkerMetaChip(
                            label: processStatus,
                            icon: Icons.memory_outlined,
                            color: GrokkerColors.signalBlueBright,
                          ),
                          GrokkerMetaChip(
                            label: initialized ? 'ACP ready' : 'ACP pending',
                            icon: Icons.check_circle_outline,
                            color: initialized
                                ? GrokkerColors.mapGreen
                                : GrokkerColors.slate,
                          ),
                        ],
                      ),
                      const SizedBox(height: GrokkerSpacing.s8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(GrokkerSpacing.s8),
                        decoration: BoxDecoration(
                          color: GrokkerSurfaces.voidFloor,
                          borderRadius: BorderRadius.circular(GrokkerRadius.input),
                          border: Border.all(color: GrokkerColors.gunmetal),
                        ),
                        child: SelectableText(
                          grokPath ?? GrokCliLocatorService.officialGrokPath() ?? '',
                          style: GrokkerTypography.mono(size: 10),
                        ),
                      ),
                      if (lastError != null) ...[
                        const SizedBox(height: GrokkerSpacing.s8),
                        Container(
                          padding: const EdgeInsets.all(GrokkerSpacing.s8),
                          decoration: BoxDecoration(
                            color: GrokkerColors.errorRedMuted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(GrokkerRadius.input),
                            border: Border.all(
                              color: GrokkerColors.errorRed.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            lastError!,
                            style: GrokkerTypography.caption(color: GrokkerColors.errorRed),
                          ),
                        ),
                      ],
                      const SizedBox(height: GrokkerSpacing.s12),
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
                const SizedBox(height: GrokkerSpacing.s24),
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
}

class _InspectorCard extends StatelessWidget {
  const _InspectorCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.accentColor = GrokkerColors.signalBlue,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GrokkerSpacing.s12),
      child: GrokkerPanel(
        padding: const EdgeInsets.all(GrokkerSpacing.s16),
        radius: GrokkerRadius.chip,
        color: GrokkerSurfaces.deepPanel,
        accentStrip: true,
        accentColor: accentColor,
        border: BorderSide(color: GrokkerColors.gunmetal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: GrokkerColors.slate),
                const SizedBox(width: GrokkerSpacing.s8),
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
      ),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  const _StyledDropdown({
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
        color: GrokkerSurfaces.voidFloor,
        borderRadius: BorderRadius.circular(GrokkerRadius.input),
        border: Border.all(color: GrokkerColors.gunmetal),
      ),
      padding: const EdgeInsets.symmetric(horizontal: GrokkerSpacing.s12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: hint != null
              ? Text(hint!, style: GrokkerTypography.bodySm(color: GrokkerColors.slate))
              : null,
          dropdownColor: GrokkerSurfaces.overlay,
          borderRadius: BorderRadius.circular(GrokkerRadius.chip),
          icon: const Icon(Icons.expand_more, color: GrokkerColors.slate, size: 18),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}