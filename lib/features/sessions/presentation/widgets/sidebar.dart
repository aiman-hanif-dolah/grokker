import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../shared/models/grok_model.dart';
import '../../../../shared/models/grok_process_status.dart';
import '../../../../shared/models/thinking_effort.dart';
import '../../../../shared/models/workspace_info.dart';
import '../../../../shared/widgets/status_dot.dart';
import '../../../../styles/design_tokens.dart';
import '../../../../styles/grokker_components.dart';
import '../../../../styles/grokker_typography.dart';
import '../../domain/models/app_session.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.workspace,
    required this.sessions,
    required this.activeSessionId,
    required this.searchQuery,
    required this.processStatus,
    required this.model,
    required this.effort,
    required this.onOpenWorkspace,
    required this.onNewSession,
    required this.onSelectSession,
    required this.onSearchChanged,
    required this.onRenameSession,
    required this.onDeleteSession,
    this.onToggleControls,
  });

  final WorkspaceInfo? workspace;
  final List<AppSession> sessions;
  final String? activeSessionId;
  final String searchQuery;
  final GrokProcessStatus processStatus;
  final GrokModel model;
  final ThinkingEffort effort;
  final VoidCallback onOpenWorkspace;
  final VoidCallback onNewSession;
  final void Function(String id) onSelectSession;
  final void Function(String query) onSearchChanged;
  final void Function(String id, String title) onRenameSession;
  final void Function(String id) onDeleteSession;
  final VoidCallback? onToggleControls;

  @override
  Widget build(BuildContext context) {
    final theme = GrokkerThemeExtension.of(context);

    return Container(
      width: GrokkerSpacing.sidebarWidth,
      decoration: BoxDecoration(
        color: theme.panel,
        border: Border(right: BorderSide(color: theme.panelBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BrandHeader(theme: theme, onToggleControls: onToggleControls),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _WorkspaceCard(
                  workspace: workspace,
                  onOpenWorkspace: onOpenWorkspace,
                  theme: theme,
                ),
                const SizedBox(height: 12),
                GrokkerSearchField(
                  key: const ValueKey('search_sessions'),
                  hint: 'Search sessions',
                  onChanged: onSearchChanged,
                ),
                const SizedBox(height: 8),
                GrokkerPrimaryButton(
                  key: const ValueKey('new_session'),
                  label: 'New session',
                  icon: Icons.add_rounded,
                  dense: true,
                  expanded: true,
                  onPressed: onNewSession,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const GrokkerEyebrow('Sessions'),
                    const Spacer(),
                    GrokkerMetaChip(
                      label: '${sessions.length}',
                      icon: Icons.chat_bubble_outline_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: GrokkerSpacing.s24,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 32,
                            color: GrokkerColors.slate.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: GrokkerSpacing.s8),
                          Text(
                            'No sessions yet',
                            style: GrokkerTypography.bodySm(
                              color: GrokkerColors.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...sessions.map(
                    (session) => _SessionTile(
                      session: session,
                      selected: session.id == activeSessionId,
                      onTap: () => onSelectSession(session.id),
                      onRename: () => _renameDialog(context, session),
                      onDelete: () => onDeleteSession(session.id),
                      theme: theme,
                    ),
                  ),
              ],
            ),
          ),
          const GrokkerSurfaceDivider(),
          _StatusFooter(
            processStatus: processStatus,
            model: model,
            effort: effort,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Future<void> _renameDialog(BuildContext context, AppSession session) async {
    final controller = TextEditingController(text: session.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rename session', style: GrokkerTypography.headingSm()),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          GrokkerGhostButton(
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx),
          ),
          GrokkerPrimaryButton(
            label: 'Save',
            dense: true,
            onPressed: () => Navigator.pop(ctx, controller.text),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      onRenameSession(session.id, result.trim());
    }
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.theme, this.onToggleControls});

  final GrokkerThemeExtension theme;
  final VoidCallback? onToggleControls;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: GrokkerSpacing.navHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: GrokkerSpacing.s16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(GrokkerRadius.input),
              child: Image.asset(
                'assets/branding/grokker_logo_48.png',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: GrokkerSpacing.s12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grokker',
                    style: GrokkerTypography.label(color: theme.headingText),
                  ),
                  Text(
                    'interactive terminal',
                    style: GrokkerTypography.caption(color: GrokkerColors.fog),
                  ),
                ],
              ),
            ),
            if (onToggleControls != null)
              GrokkerIconFrameButton(
                icon: Icons.tune_rounded,
                tooltip: 'Controls (Ctrl+Shift+I)',
                accent: true,
                onPressed: onToggleControls,
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.workspace,
    required this.onOpenWorkspace,
    required this.theme,
  });

  final WorkspaceInfo? workspace;
  final VoidCallback onOpenWorkspace;
  final GrokkerThemeExtension theme;

  @override
  Widget build(BuildContext context) {
    final hasWorkspace = workspace != null;

    return GrokkerPanel(
      padding: const EdgeInsets.all(GrokkerSpacing.s16),
      radius: GrokkerRadius.panel,
      color: GrokkerSurfaces.deepPanel,
      accentStrip: hasWorkspace,
      border: BorderSide(
        color: hasWorkspace
            ? GrokkerColors.signalBlue.withValues(alpha: 0.2)
            : GrokkerColors.pewter.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GrokkerAvatar(
                icon: hasWorkspace
                    ? Icons.folder_rounded
                    : Icons.folder_off_outlined,
                color: hasWorkspace
                    ? GrokkerColors.signalBlue
                    : GrokkerColors.slate,
                size: 36,
              ),
              const SizedBox(width: GrokkerSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GrokkerEyebrow('Workspace'),
                    const SizedBox(height: GrokkerSpacing.s4),
                    Text(
                      workspace?.name ?? 'No workspace',
                      style: GrokkerTypography.label(color: theme.headingText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasWorkspace) ...[
            const SizedBox(height: GrokkerSpacing.s12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(GrokkerSpacing.s8),
              decoration: BoxDecoration(
                color: GrokkerSurfaces.voidFloor,
                borderRadius: BorderRadius.circular(GrokkerRadius.input),
                border: Border.all(color: GrokkerColors.gunmetal),
              ),
              child: Text(
                workspace!.path,
                style: GrokkerTypography.mono(
                  size: 10,
                  color: theme.subtleText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (workspace!.primaryProjectType.isNotEmpty) ...[
              const SizedBox(height: GrokkerSpacing.s8),
              GrokkerMetaChip(
                label: workspace!.primaryProjectType,
                icon: Icons.code_rounded,
                color: GrokkerColors.signalBlueBright,
              ),
            ],
          ],
          const SizedBox(height: GrokkerSpacing.s12),
          GrokkerOutlinedButton(
            key: const ValueKey('open_workspace'),
            label: hasWorkspace ? 'Change folder' : 'Open folder',
            icon: Icons.folder_open_rounded,
            dense: true,
            expanded: true,
            onPressed: onOpenWorkspace,
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.theme,
  });

  final AppSession session;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final GrokkerThemeExtension theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? GrokkerColors.ember.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(GrokkerRadius.chip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GrokkerRadius.chip),
          hoverColor: GrokkerColors.ember.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GrokkerRadius.chip),
              border: Border.all(
                color: selected
                    ? GrokkerColors.ember.withValues(alpha: 0.4)
                    : theme.panelBorder,
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 2,
                    color: selected ? GrokkerColors.ember : Colors.transparent,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 2, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            style: GrokkerTypography.bodySm(
                              color: selected
                                  ? GrokkerColors.snow
                                  : theme.bodyText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatRelative(session.updatedAt)}'
                            '${session.messages.isNotEmpty ? ' · ${session.messages.length} msgs' : ''}',
                            style: GrokkerTypography.caption(
                              color: GrokkerColors.fog,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 16,
                      color: GrokkerColors.fog,
                    ),
                    color: theme.raised,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GrokkerRadius.chip),
                      side: BorderSide(color: theme.panelBorder),
                    ),
                    onSelected: (value) {
                      if (value == 'rename') onRename();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(
                          'Rename',
                          style: GrokkerTypography.bodySm(),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: GrokkerTypography.bodySm(
                            color: GrokkerColors.errorRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatRelative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return dt.toLocal().toString().substring(0, 10);
  }
}

class _StatusFooter extends StatelessWidget {
  const _StatusFooter({
    required this.processStatus,
    required this.model,
    required this.effort,
    required this.theme,
  });

  final GrokProcessStatus processStatus;
  final GrokModel model;
  final ThinkingEffort effort;
  final GrokkerThemeExtension theme;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(processStatus);
    final isRunning = processStatus.state == GrokProcessState.running;

    return Padding(
      padding: const EdgeInsets.all(GrokkerSpacing.s16),
      child: GrokkerPanel(
        padding: const EdgeInsets.all(GrokkerSpacing.s12),
        radius: GrokkerRadius.chip,
        color: GrokkerSurfaces.deepPanel,
        border: BorderSide(color: GrokkerColors.gunmetal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusDot(
              color: statusColor,
              label: 'Grok: ${processStatus.state.name}',
              pulse: isRunning,
            ),
            const SizedBox(height: GrokkerSpacing.s8),
            Wrap(
              spacing: GrokkerSpacing.s8,
              runSpacing: GrokkerSpacing.s8,
              children: [
                GrokkerMetaChip(
                  label: model.displayName,
                  icon: Icons.psychology_outlined,
                  color: GrokkerColors.signalBlueBright,
                ),
                GrokkerMetaChip(
                  label: effort.displayName,
                  icon: Icons.bolt_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(GrokProcessStatus status) {
    switch (status.state) {
      case GrokProcessState.running:
        return GrokkerColors.mapGreen;
      case GrokProcessState.starting:
      case GrokProcessState.restarting:
        return GrokkerColors.signalBlueBright;
      case GrokProcessState.failed:
        return GrokkerColors.errorRed;
      case GrokProcessState.stopped:
        return GrokkerColors.steel;
    }
  }
}
