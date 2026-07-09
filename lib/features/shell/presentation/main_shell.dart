import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/service_locator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/attachment_item.dart';
import '../../../shared/models/chat_message.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/file_drop_scope.dart';
import '../../../styles/design_tokens.dart';
import '../../../styles/grokker_components.dart';
import '../../../styles/grokker_typography.dart';
import '../../acp/presentation/cubit/acp_connection_cubit.dart';
import '../../acp/presentation/cubit/grok_cli_cubit.dart';
import '../../attachments/presentation/cubit/attachment_cubit.dart';
import '../../chat/presentation/cubit/chat_cubit.dart';
import '../../chat/presentation/widgets/chat_message_tile.dart';
import '../../chat/presentation/widgets/composer.dart';
import '../../diagnostics/presentation/cubit/diagnostics_cubit.dart';
import '../../diagnostics/presentation/widgets/diagnostics_panel.dart';
import '../../diagnostics/presentation/widgets/inspector_panel.dart';
import '../../diff_viewer/presentation/cubit/diff_cubit.dart';
import '../../goal/presentation/cubit/goal_cubit.dart';
import '../../sessions/domain/models/app_session.dart';
import '../../sessions/presentation/cubit/session_cubit.dart';
import '../../sessions/presentation/widgets/sidebar.dart';
import '../../settings/presentation/cubit/settings_cubit.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../workspace/presentation/cubit/workspace_cubit.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _composerController = TextEditingController();
  final _composerFocus = FocusNode();
  bool _inspectorVisible = true;
  bool _isDraggingFiles = false;

  final _locator = ServiceLocator.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locator.chatCubit.setActiveSession(
        _locator.sessionCubit.state.activeSession,
      );
    });
  }

  @override
  void dispose() {
    _composerController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _locator.settingsCubit),
        BlocProvider.value(value: _locator.grokCliCubit),
        BlocProvider.value(value: _locator.acpConnectionCubit),
        BlocProvider.value(value: _locator.workspaceCubit),
        BlocProvider.value(value: _locator.sessionCubit),
        BlocProvider.value(value: _locator.chatCubit),
        BlocProvider.value(value: _locator.attachmentCubit),
        BlocProvider.value(value: _locator.diagnosticsCubit),
        BlocProvider.value(value: _locator.diffCubit),
        BlocProvider.value(value: _locator.goalCubit),
      ],
      child: CallbackShortcuts(
        bindings: _shortcuts(),
        child: Focus(
          autofocus: true,
          child: BlocListener<SessionCubit, SessionState>(
            listenWhen: (prev, curr) =>
                prev.activeSessionId != curr.activeSessionId,
            listener: (context, sessionState) {
              _locator.chatCubit.setActiveSession(sessionState.activeSession);
              _maybeRestoreWorkspace(context, sessionState.activeSession);
            },
            child: BlocListener<SessionCubit, SessionState>(
              listenWhen: (prev, curr) {
                final prevSession = prev.activeSession;
                final currSession = curr.activeSession;
                if (prevSession?.id != currSession?.id) return false;
                return prevSession?.acpSessionId != currSession?.acpSessionId ||
                    prevSession?.messages.length !=
                        currSession?.messages.length;
              },
              listener: (context, sessionState) {
                _locator.chatCubit.setActiveSession(sessionState.activeSession);
              },
              child: BlocBuilder<SessionCubit, SessionState>(
                builder: (context, sessionState) {
                  final session = sessionState.activeSession;

                  return Scaffold(
                backgroundColor: GrokkerSurfaces.voidFloor,
                body: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          BlocBuilder<GrokCliCubit, GrokCliState>(
                            builder: (context, cli) {
                              return BlocBuilder<
                                AcpConnectionCubit,
                                AcpConnectionState
                              >(
                                builder: (context, acp) {
                                  return BlocBuilder<
                                    WorkspaceCubit,
                                    WorkspaceState
                                  >(
                                    builder: (context, ws) {
                                      return Sidebar(
                                        workspace: ws.workspace,
                                        sessions: sessionState.filteredSessions,
                                        activeSessionId:
                                            sessionState.activeSessionId,
                                        searchQuery: sessionState.searchQuery,
                                        processStatus: acp.processStatus,
                                        model:
                                            session?.selectedModel ??
                                            _locator
                                                .settingsCubit
                                                .state
                                                .settings
                                                .defaultModel,
                                        effort:
                                            session?.selectedEffort ??
                                            _locator
                                                .settingsCubit
                                                .state
                                                .settings
                                                .defaultEffort,
                                        onOpenWorkspace: () =>
                                            _openWorkspace(context),
                                        onNewSession: () =>
                                            _newSession(context),
                                        onSelectSession: (id) => context
                                            .read<SessionCubit>()
                                            .selectSession(id),
                                        onSearchChanged: (q) => context
                                            .read<SessionCubit>()
                                            .setSearchQuery(q),
                                        onSettings: () =>
                                            _openSettings(context),
                                        onRenameSession: (id, title) => context
                                            .read<SessionCubit>()
                                            .renameSession(id, title),
                                        onDeleteSession: (id) => context
                                            .read<SessionCubit>()
                                            .deleteSession(id),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                          Expanded(child: _chatArea(session)),
                          BlocBuilder<DiagnosticsCubit, DiagnosticsState>(
                            builder: (context, diag) {
                              return BlocBuilder<DiffCubit, DiffState>(
                                builder: (context, diffState) {
                                  return BlocBuilder<
                                    AttachmentCubit,
                                    AttachmentState
                                  >(
                                    builder: (context, att) {
                                      return BlocBuilder<
                                        WorkspaceCubit,
                                        WorkspaceState
                                      >(
                                        builder: (context, ws) {
                                          return BlocBuilder<
                                            AcpConnectionCubit,
                                            AcpConnectionState
                                          >(
                                            builder: (context, acp) {
                                              return BlocBuilder<
                                                GrokCliCubit,
                                                GrokCliState
                                              >(
                                                builder: (context, cli) {
                                                  return BlocBuilder<
                                                    ChatCubit,
                                                    ChatState
                                                  >(
                                                    builder: (context, chat) {
                                                      return InspectorPanel(
                                                        visible:
                                                            _inspectorVisible,
                                                        workspace: ws.workspace,
                                                        model:
                                                            session
                                                                ?.selectedModel ??
                                                            _locator
                                                                .settingsCubit
                                                                .state
                                                                .settings
                                                                .defaultModel,
                                                        effort:
                                                            session
                                                                ?.selectedEffort ??
                                                            _locator
                                                                .settingsCubit
                                                                .state
                                                                .settings
                                                                .defaultEffort,
                                                        attachments:
                                                            att.attachments,
                                                        acpSessionId: session
                                                            ?.acpSessionId,
                                                        diffs: diffState.files,
                                                        selectedDiff:
                                                            diffState.selected,
                                                        pendingPermission: chat
                                                            .pendingPermission,
                                                        diagnostics: diag,
                                                        processStatus: acp
                                                            .processStatus
                                                            .state
                                                            .name,
                                                        initialized:
                                                            acp.initialized,
                                                        grokVersion:
                                                            cli.version,
                                                        grokPath:
                                                            cli.resolvedPath,
                                                        lastError:
                                                            acp.lastError ??
                                                            chat
                                                                .lastError
                                                                ?.message,
                                                        onModelChanged: (m) =>
                                                            context
                                                                .read<
                                                                  ChatCubit
                                                                >()
                                                                .setModel(m),
                                                        onEffortChanged: (e) =>
                                                            context
                                                                .read<
                                                                  ChatCubit
                                                                >()
                                                                .setEffort(e),
                                                        onSelectDiff: (id) =>
                                                            context
                                                                .read<
                                                                  DiffCubit
                                                                >()
                                                                .select(id),
                                                        onApprovePermission:
                                                            () => context
                                                                .read<
                                                                  ChatCubit
                                                                >()
                                                                .respondToPermission(
                                                                  true,
                                                                ),
                                                        onDenyPermission: () =>
                                                            context
                                                                .read<
                                                                  ChatCubit
                                                                >()
                                                                .respondToPermission(
                                                                  false,
                                                                ),
                                                        onCopyDiff: () {},
                                                        onToggleDiagnostics:
                                                            () => context
                                                                .read<
                                                                  DiagnosticsCubit
                                                                >()
                                                                .toggle(),
                                                      );
                                                    },
                                                  );
                                                },
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    BlocBuilder<DiagnosticsCubit, DiagnosticsState>(
                      builder: (context, diag) {
                        return DiagnosticsPanel(
                          state: diag,
                          onRestart: () => _restartGrok(context),
                          onClose: () => context
                              .read<DiagnosticsCubit>()
                              .setVisible(false),
                        );
                      },
                    ),
                    _statusBar(context, session),
                  ],
                ),
              );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chatArea(AppSession? session) {
    return FileDropScope(
      onDraggingChanged: (dragging) {
        if (_isDraggingFiles != dragging) {
          setState(() => _isDraggingFiles = dragging);
        }
      },
      onFilesDropped: (files) {
        final settings = context.read<SettingsCubit>().state.settings;
        context.read<AttachmentCubit>().addDropItems(
          files,
          warningThreshold: settings.attachmentWarningBytes,
        );
        _composerFocus.requestFocus();
      },
      child: Container(
        decoration: const BoxDecoration(
          color: GrokkerSurfaces.voidFloor,
          border: Border(
            left: BorderSide(color: Color(0x10FFFFFF)),
            right: BorderSide(color: Color(0x10FFFFFF)),
          ),
        ),
        child: Column(
      children: [
        Expanded(
          child: BlocBuilder<ChatCubit, ChatState>(
            builder: (context, chat) {
              final hiddenTools = context
                  .read<SettingsCubit>()
                  .state
                  .settings
                  .hiddenTools;
              final filteredMessages = session?.messages.where((m) {
                if (m.role != ChatMessageRole.tool) return true;
                final toolName = (m.title ?? '').toLowerCase();
                return !hiddenTools.contains(toolName);
              }).toList() ?? [];

              return Column(
                children: [
                  if (chat.lastError != null)
                    ErrorBanner(error: chat.lastError!),
                  Expanded(
                    child: session == null
                        ? _EmptyWorkspaceState(
                            onOpenWorkspace: () => _openWorkspace(context),
                          )
                        : filteredMessages.isEmpty && session.messages.any((m) =>
                              m.role == ChatMessageRole.tool &&
                              hiddenTools.contains(
                                (m.title ?? '').toLowerCase(),
                              ))
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(GrokkerSpacing.s24),
                                  child: Text(
                                    'All tools hidden. Open Settings → Tools to unhide them.',
                                    style: GrokkerTypography.bodySm(
                                      color: GrokkerColors.fog,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : filteredMessages.isEmpty
                            ? _EmptyChatState(sessionTitle: session.title)
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: GrokkerSpacing.chatMaxWidth + 96,
                              ),
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: GrokkerSpacing.s24,
                                  vertical: GrokkerSpacing.s20,
                                ),
                                itemCount: filteredMessages.length,
                                itemBuilder: (_, i) =>
                                    ChatMessageTile(message: filteredMessages[i]),
                              ),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        BlocBuilder<ChatCubit, ChatState>(
          builder: (context, chat) {
            return BlocBuilder<AttachmentCubit, AttachmentState>(
              builder: (context, att) {
                return BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (context, settings) {
                    return BlocBuilder<GoalCubit, GoalState>(
                      builder: (context, goal) {
                        return Composer(
                          controller: _composerController,
                          focusNode: _composerFocus,
                          attachments: att.attachments,
                          isStreaming: chat.isStreaming,
                          isDraggingFiles: _isDraggingFiles,
                          settings: settings.settings,
                          isGoalActive: goal.isActive,
                          goalIteration: goal.iteration,
                          onToggleGoal: () {
                            final cubit = context.read<GoalCubit>();
                            if (goal.isActive) {
                              cubit.stopGoal();
                            } else {
                              final text = _composerController.text.trim();
                              if (text.isNotEmpty) {
                                cubit.startGoal(text);
                              }
                            }
                          },
                          onSend: () => _send(context),
                          onStop: () =>
                              context.read<ChatCubit>().cancelGeneration(),
                          onAttachFiles: () =>
                              context.read<AttachmentCubit>().pickFiles(
                                warningThreshold:
                                    settings.settings.attachmentWarningBytes,
                              ),
                          onAttachImages: () =>
                              context.read<AttachmentCubit>().pickImages(
                                warningThreshold:
                                    settings.settings.attachmentWarningBytes,
                              ),
                          onPaste: () => context
                              .read<AttachmentCubit>()
                              .pasteFromClipboard(
                                warningThreshold:
                                    settings.settings.attachmentWarningBytes,
                              ),
                          onRemoveAttachment: (id) =>
                              context.read<AttachmentCubit>().remove(id),
                          onTogglePin: (id) =>
                              context.read<AttachmentCubit>().togglePin(id),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    ),
      ),
    );
  }

  Widget _statusBar(BuildContext context, AppSession? session) {
    return BlocBuilder<AcpConnectionCubit, AcpConnectionState>(
      builder: (context, acp) {
        return BlocBuilder<WorkspaceCubit, WorkspaceState>(
          builder: (context, ws) {
            return BlocBuilder<ChatCubit, ChatState>(
              builder: (context, chat) {
                final grokState = acp.processStatus.state.name;
                final isStreaming = chat.isStreaming;

                return Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(
                    horizontal: GrokkerSpacing.s20,
                  ),
                  decoration: BoxDecoration(
                    color: GrokkerSurfaces.deepPanel,
                    border: Border(
                      top: BorderSide(
                        color: GrokkerColors.gunmetal.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 12,
                        color: GrokkerColors.slate,
                      ),
                      const SizedBox(width: GrokkerSpacing.s8),
                      Expanded(
                        child: Text(
                          _workspaceStatusLabel(ws),
                          style: GrokkerTypography.mono(size: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GrokkerMetaChip(
                        label: 'Grok: $grokState',
                        icon: Icons.terminal,
                        color: grokState == 'running'
                            ? GrokkerColors.mapGreen
                            : GrokkerColors.slate,
                      ),
                      const SizedBox(width: GrokkerSpacing.s8),
                      GrokkerMetaChip(
                        label: isStreaming ? 'Streaming…' : chat.lastActionStatus,
                        icon: isStreaming ? Icons.sync : Icons.check_circle_outline,
                        color: isStreaming
                            ? GrokkerColors.signalBlueBright
                            : GrokkerColors.slate,
                      ),

                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    final mod = Platform.isMacOS
        ? LogicalKeyboardKey.meta
        : LogicalKeyboardKey.control;

    return {
      LogicalKeySet(mod, LogicalKeyboardKey.keyO): () =>
          _openWorkspace(context),
      LogicalKeySet(mod, LogicalKeyboardKey.keyN): () => _newSession(context),
      LogicalKeySet(mod, LogicalKeyboardKey.comma): () =>
          _openSettings(context),
      LogicalKeySet(mod, LogicalKeyboardKey.keyL): () =>
          _composerFocus.requestFocus(),
      LogicalKeySet(
        mod,
        LogicalKeyboardKey.shift,
        LogicalKeyboardKey.keyD,
      ): () =>
          context.read<DiagnosticsCubit>().toggle(),
      LogicalKeySet(
        mod,
        LogicalKeyboardKey.shift,
        LogicalKeyboardKey.keyI,
      ): () =>
          setState(() => _inspectorVisible = !_inspectorVisible),
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          context.read<ChatCubit>().cancelGeneration(),
    };
  }

  void _maybeRestoreWorkspace(BuildContext context, AppSession? session) {
    final path = session?.workspacePath;
    if (path == null || path.isEmpty) return;
    final current = context.read<WorkspaceCubit>().state.workspace?.path;
    if (current == path) return;
    unawaited(context.read<WorkspaceCubit>().setWorkspace(path));
  }

  String _workspaceStatusLabel(WorkspaceState ws) {
    final path = ws.workspace?.path ?? 'none';
    if (ws.isLearning) {
      return 'Workspace: $path · ${ws.learningStatus ?? 'Learning…'}';
    }
    if (ws.memory != null) {
      final source = ws.fromCache ? 'cached memory' : 'memory updated';
      return 'Workspace: $path · $source (${ws.memory!.fileCount} files)';
    }
    return 'Workspace: $path';
  }

  Future<void> _openWorkspace(BuildContext context) async {
    await context.read<WorkspaceCubit>().openFolder();
    final ws = context.read<WorkspaceCubit>().state.workspace;
    if (ws != null) {
      _locator.acpConnectionCubit.updateWorkspace(ws.path);
      _locator.clientRequestHandler.workspacePath = ws.path;
      if (_locator.settingsCubit.state.settings.autoCreateSession) {
        await _newSession(context);
      }
    }
  }

  Future<void> _newSession(BuildContext context) async {
    final ws = context.read<WorkspaceCubit>().state.workspace;
    final settings = context.read<SettingsCubit>().state.settings;
    await context.read<SessionCubit>().createSession(
      workspacePath: ws?.path ?? '',
      model: settings.defaultModel,
      effort: settings.defaultEffort,
      processCommand: _locator.grokCliCubit.state.command,
    );
  }

  Future<void> _send(BuildContext context) async {
    final text = _composerController.text.trim();
    final attachmentCubit = context.read<AttachmentCubit>();
    final attachments = attachmentCubit.state.attachments;
    if (text.isEmpty && attachments.isEmpty) return;

    final settings = context.read<SettingsCubit>().state.settings;
    final attachmentsToSend = List<AttachmentItem>.from(attachments);

    // Clear composer immediately — don't wait for ACP/session/prompt prep.
    _composerController.clear();
    attachmentCubit.clearUnpinned();

    final acpState = context.read<AcpConnectionCubit>().state;
    if (!acpState.initialized) {
      final cli = context.read<GrokCliCubit>().state;
      if (cli.found && cli.command != null) {
        await context.read<AcpConnectionCubit>().start(
          command: cli.command!,
          args: cli.args,
        );
      }
    }

    var session = context.read<SessionCubit>().state.activeSession;
    if (session == null) {
      await _newSession(context);
      session = context.read<SessionCubit>().state.activeSession;
      if (session == null) return;
    }

    final attachmentSection = await attachmentCubit.buildReferenceSectionFor(
      attachmentsToSend,
      inlineSmallText: settings.inlineSmallTextAttachments,
    );

    final caps =
        _locator.acpClient.agentCapabilities?['promptCapabilities']
            as Map<String, dynamic>?;
    final supportsImages = caps?['image'] == true;
    final supportsEmbedded = caps?['embeddedContext'] == true;

    final wsState = context.read<WorkspaceCubit>().state;

    await context.read<ChatCubit>().sendMessage(
      session: session,
      userText: text,
      workspace: wsState.workspace,
      workspaceMemory: wsState.memory,
      attachments: attachmentsToSend,
      supportsImages: supportsImages,
      supportsEmbeddedContext: supportsEmbedded,
      attachmentSection: attachmentSection,
      settings: settings,
    );
  }

  void _openSettings(BuildContext context) {
    final settings = context.read<SettingsCubit>().state.settings;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          settings: settings,
          onSave: (s) async {
            await context.read<SettingsCubit>().update(s);
            _locator.clientRequestHandler.approvalMode = s.approvalMode;
            if (context.mounted) Navigator.pop(context);
          },
          onReset: () async {
            await context.read<SettingsCubit>().reset();
            if (context.mounted) Navigator.pop(context);
          },
          onClearCache: () async {
            await context.read<SessionCubit>().load();
          },
        ),
      ),
    );
  }

  Future<void> _restartGrok(BuildContext context) async {
    final cli = context.read<GrokCliCubit>().state;
    await context.read<AcpConnectionCubit>().restart(
      command: cli.command ?? AppConstants.defaultGrokCommand,
      args: cli.args,
    );
  }
}

class _EmptyWorkspaceState extends StatelessWidget {
  const _EmptyWorkspaceState({required this.onOpenWorkspace});

  final VoidCallback onOpenWorkspace;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GrokkerSpacing.s48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: GrokkerGradients.signalGlow,
                  borderRadius: BorderRadius.circular(GrokkerRadius.panel),
                  boxShadow: GrokkerShadows.glow(GrokkerColors.signalBlue, blur: 24),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 36,
                  color: GrokkerColors.white,
                ),
              ),
              const SizedBox(height: GrokkerSpacing.s32),
              Text(
                'Build with Grok',
                style: GrokkerTypography.display(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: GrokkerSpacing.s16),
              Text(
                'Open a workspace and create a session to start building with Grok.',
                style: GrokkerTypography.subheading(color: GrokkerColors.ash),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: GrokkerSpacing.s32),
              GrokkerPrimaryButton(
                label: 'Open folder',
                icon: Icons.folder_open_rounded,
                onPressed: onOpenWorkspace,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.sessionTitle});

  final String sessionTitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GrokkerSpacing.s48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GrokkerAvatar(
              icon: Icons.chat_bubble_outline_rounded,
              color: GrokkerColors.signalBlue,
              size: 56,
            ),
            const SizedBox(height: GrokkerSpacing.s24),
            Text(
              sessionTitle,
              style: GrokkerTypography.headingSm(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: GrokkerSpacing.s8),
            Text(
              'Send a message to begin.',
              style: GrokkerTypography.bodySm(color: GrokkerColors.slate),
            ),
            const SizedBox(height: GrokkerSpacing.s24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: GrokkerSpacing.s8,
              children: const [
                GrokkerMetaChip(
                  label: 'Ask questions',
                  icon: Icons.help_outline,
                ),
                GrokkerMetaChip(
                  label: 'Write code',
                  icon: Icons.code,
                ),
                GrokkerMetaChip(
                  label: 'Attach files',
                  icon: Icons.attach_file,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
