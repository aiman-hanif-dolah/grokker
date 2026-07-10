import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/service_locator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/attachment_item.dart';
import '../../../shared/models/chat_message.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../app/app_theme.dart';
import '../../../styles/design_tokens.dart';
import '../../../styles/grokker_components.dart';
import '../../../styles/grokker_typography.dart';
import '../../acp/presentation/cubit/acp_connection_cubit.dart';
import '../../acp/presentation/cubit/grok_cli_cubit.dart';
import '../../attachments/presentation/cubit/attachment_cubit.dart';
import '../../chat/presentation/cubit/chat_cubit.dart';
import '../../diagnostics/presentation/cubit/diagnostics_cubit.dart';
import '../../diagnostics/presentation/widgets/diagnostics_panel.dart';
import '../../diagnostics/presentation/widgets/inspector_panel.dart';
import '../../diff_viewer/presentation/cubit/diff_cubit.dart';
import '../../sessions/domain/models/app_session.dart';
import '../../sessions/presentation/cubit/session_cubit.dart';
import '../../sessions/presentation/widgets/sidebar.dart';
import '../../goal/presentation/cubit/goal_cubit.dart';
import '../../models/presentation/cubit/models_cubit.dart';
import '../../multitask/presentation/cubit/multitask_cubit.dart';
import '../../settings/presentation/cubit/settings_cubit.dart';
import '../../terminal/presentation/widgets/terminal_view.dart';
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
        BlocProvider.value(value: _locator.multitaskCubit),
        BlocProvider.value(value: _locator.modelsCubit),
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
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                                            sessions:
                                                sessionState.filteredSessions,
                                            activeSessionId:
                                                sessionState.activeSessionId,
                                            searchQuery:
                                                sessionState.searchQuery,
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
                                            onRenameSession: (id, title) =>
                                                context
                                                    .read<SessionCubit>()
                                                    .renameSession(id, title),
                                            onDeleteSession: (id) => context
                                                .read<SessionCubit>()
                                                .deleteSession(id),
                                            onToggleControls: () => setState(
                                              () => _inspectorVisible =
                                                  !_inspectorVisible,
                                            ),
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
                                                          return BlocBuilder<
                                                            SettingsCubit,
                                                            SettingsState
                                                          >(
                                                            builder:
                                                                (
                                                                  context,
                                                                  settingsState,
                                                                ) {
                                                                  return BlocBuilder<
                                                                    ModelsCubit,
                                                                    ModelsState
                                                                  >(
                                                                    builder:
                                                                        (
                                                                          context,
                                                                          modelsState,
                                                                        ) {
                                                                          return BlocBuilder<
                                                                            GoalCubit,
                                                                            GoalState
                                                                          >(
                                                                            builder:
                                                                                (
                                                                                  context,
                                                                                  goalState,
                                                                                ) {
                                                                                  return BlocBuilder<
                                                                                    MultitaskCubit,
                                                                                    MultitaskState
                                                                                  >(
                                                                                    builder:
                                                                                        (
                                                                                          context,
                                                                                          multiState,
                                                                                        ) {
                                                                                          return InspectorPanel(
                                                                                            visible: _inspectorVisible,
                                                                                            workspace: ws.workspace,
                                                                                            model:
                                                                                                session?.selectedModel ??
                                                                                                settingsState.settings.defaultModel,
                                                                                            availableModels: modelsState.models,
                                                                                            effort:
                                                                                                session?.selectedEffort ??
                                                                                                settingsState.settings.defaultEffort,
                                                                                            settings: settingsState.settings,
                                                                                            goalState: goalState,
                                                                                            multitaskState: multiState,
                                                                                            onStopGoal: () => context
                                                                                                .read<
                                                                                                  GoalCubit
                                                                                                >()
                                                                                                .stopGoal(),
                                                                                            onToggleMultitask: () => _toggleMultitaskExclusive(
                                                                                              context,
                                                                                            ),
                                                                                            onToggleSubagents:
                                                                                                (
                                                                                                  v,
                                                                                                ) => context
                                                                                                    .read<
                                                                                                      MultitaskCubit
                                                                                                    >()
                                                                                                    .setUseSubagents(
                                                                                                      v,
                                                                                                    ),
                                                                                            onQueueMultitaskFromText:
                                                                                                (
                                                                                                  bulk,
                                                                                                ) => context
                                                                                                    .read<
                                                                                                      MultitaskCubit
                                                                                                    >()
                                                                                                    .enqueueFromBulk(
                                                                                                      bulk,
                                                                                                    ),
                                                                                            onClearMultitaskQueue: () => context
                                                                                                .read<
                                                                                                  MultitaskCubit
                                                                                                >()
                                                                                                .clearQueue(),
                                                                                            onRunMultitaskQueue: () => context
                                                                                                .read<
                                                                                                  ChatCubit
                                                                                                >()
                                                                                                .runNextMultitask(),
                                                                                            attachments: att.attachments,
                                                                                            acpSessionId: session?.acpSessionId,
                                                                                            diffs: diffState.files,
                                                                                            selectedDiff: diffState.selected,
                                                                                            pendingPermission: chat.pendingPermission,
                                                                                            diagnostics: diag,
                                                                                            processStatus: acp.processStatus.state.name,
                                                                                            initialized: acp.initialized,
                                                                                            grokVersion: cli.version,
                                                                                            grokPath: cli.resolvedPath,
                                                                                            lastError:
                                                                                                acp.lastError ??
                                                                                                chat.lastError?.message,
                                                                                            onModelChanged:
                                                                                                (
                                                                                                  m,
                                                                                                ) => context
                                                                                                    .read<
                                                                                                      ChatCubit
                                                                                                    >()
                                                                                                    .setModel(
                                                                                                      m,
                                                                                                    ),
                                                                                            onEffortChanged:
                                                                                                (
                                                                                                  e,
                                                                                                ) => context
                                                                                                    .read<
                                                                                                      ChatCubit
                                                                                                    >()
                                                                                                    .setEffort(
                                                                                                      e,
                                                                                                    ),
                                                                                            onSettingsChanged:
                                                                                                (
                                                                                                  s,
                                                                                                ) async {
                                                                                                  await context
                                                                                                      .read<
                                                                                                        SettingsCubit
                                                                                                      >()
                                                                                                      .update(
                                                                                                        s,
                                                                                                      );
                                                                                                  _locator.clientRequestHandler.approvalMode = s.approvalMode;
                                                                                                },
                                                                                            onSelectDiff:
                                                                                                (
                                                                                                  id,
                                                                                                ) => context
                                                                                                    .read<
                                                                                                      DiffCubit
                                                                                                    >()
                                                                                                    .select(
                                                                                                      id,
                                                                                                    ),
                                                                                            onApprovePermission: () => context
                                                                                                .read<
                                                                                                  ChatCubit
                                                                                                >()
                                                                                                .respondToPermission(
                                                                                                  true,
                                                                                                ),
                                                                                            onDenyPermission: () => context
                                                                                                .read<
                                                                                                  ChatCubit
                                                                                                >()
                                                                                                .respondToPermission(
                                                                                                  false,
                                                                                                ),
                                                                                            onCopyDiff: () {
                                                                                              final diff = diffState.selected;
                                                                                              if (diff ==
                                                                                                  null) {
                                                                                                return;
                                                                                              }
                                                                                              Clipboard.setData(
                                                                                                ClipboardData(
                                                                                                  text: diff.unifiedDiff,
                                                                                                ),
                                                                                              );
                                                                                            },
                                                                                            onToggleDiagnostics: () => context
                                                                                                .read<
                                                                                                  DiagnosticsCubit
                                                                                                >()
                                                                                                .toggle(),
                                                                                            onResetSettings: () async {
                                                                                              await context
                                                                                                  .read<
                                                                                                    SettingsCubit
                                                                                                  >()
                                                                                                  .reset();
                                                                                            },
                                                                                            onCollapse: () => setState(
                                                                                              () => _inspectorVisible = false,
                                                                                            ),
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
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, chat) {
        return BlocBuilder<AttachmentCubit, AttachmentState>(
          builder: (context, att) {
            return BlocBuilder<SettingsCubit, SettingsState>(
              builder: (context, settingsState) {
                final settings = settingsState.settings;
                final hiddenTools = settings.hiddenTools;
                final filteredMessages =
                    session?.messages.where((m) {
                      if (m.role != ChatMessageRole.tool) return true;
                      final toolName = (m.title ?? '').toLowerCase();
                      return !hiddenTools.contains(toolName);
                    }).toList() ??
                    const <ChatMessage>[];

                final wsPath = context
                    .watch<WorkspaceCubit>()
                    .state
                    .workspace
                    ?.path;
                final cwdLabel = wsPath == null || wsPath.isEmpty
                    ? null
                    : '$wsPath ›';

                return BlocBuilder<GoalCubit, GoalState>(
                  builder: (context, goal) {
                    return BlocBuilder<MultitaskCubit, MultitaskState>(
                      builder: (context, multi) {
                        return TerminalView(
                          messages: filteredMessages,
                          controller: _composerController,
                          focusNode: _composerFocus,
                          attachments: att.attachments,
                          attachmentStatus: att.statusMessage,
                          isStreaming: chat.isStreaming,
                          isDraggingFiles: _isDraggingFiles,
                          settings: settings,
                          cwdLabel: cwdLabel,
                          sessionTitle: session?.title,
                          hasWorkspace:
                              session != null ||
                              (wsPath != null && wsPath.isNotEmpty),
                          onOpenWorkspace: () => _openWorkspace(context),
                          errorBanner: chat.lastError != null
                              ? ErrorBanner(error: chat.lastError!)
                              : null,
                          isGoalActive: goal.isActive,
                          goalIteration: goal.iteration,
                          goalStatus: goal.lastStatus,
                          onToggleGoal: () => _toggleGoalExclusive(
                            context,
                            isStreaming: chat.isStreaming,
                          ),
                          isMultitaskActive: multi.enabled,
                          multitaskQueued: multi.queuedCount,
                          onToggleMultitask: () =>
                              _toggleMultitaskExclusive(context),
                          onDraggingChanged: (dragging) {
                            if (_isDraggingFiles != dragging) {
                              setState(() => _isDraggingFiles = dragging);
                            }
                          },
                          onFilesDropped: (files) {
                            context.read<AttachmentCubit>().addDropItems(
                              files,
                              warningThreshold: settings.attachmentWarningBytes,
                            );
                            _composerFocus.requestFocus();
                          },
                          onSend: () => _send(context),
                          onStop: () {
                            context.read<ChatCubit>().cancelGeneration();
                            // Stop only generation on Esc path is separate; stop button
                            // also cancels an active goal so autopilot does not resume.
                            if (context.read<GoalCubit>().state.isActive) {
                              context.read<GoalCubit>().stopGoal(
                                status: 'Goal stopped by user',
                              );
                            }
                          },
                          onAttachFiles: () =>
                              context.read<AttachmentCubit>().pickFiles(
                                warningThreshold:
                                    settings.attachmentWarningBytes,
                              ),
                          onAttachImages: () =>
                              context.read<AttachmentCubit>().pickImages(
                                warningThreshold:
                                    settings.attachmentWarningBytes,
                              ),
                          onPaste: () => context
                              .read<AttachmentCubit>()
                              .pasteFromClipboard(
                                warningThreshold:
                                    settings.attachmentWarningBytes,
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
        );
      },
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

                final theme = GrokkerThemeExtension.of(context);
                return Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(
                    horizontal: GrokkerSpacing.s16,
                  ),
                  decoration: BoxDecoration(
                    color: theme.panel,
                    border: Border(top: BorderSide(color: theme.panelBorder)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        size: 12,
                        color: GrokkerColors.fog,
                      ),
                      const SizedBox(width: GrokkerSpacing.s8),
                      Expanded(
                        child: Text(
                          _workspaceStatusLabel(ws),
                          style: GrokkerTypography.mono(
                            size: 11,
                            color: GrokkerColors.ash,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GrokkerMetaChip(
                        label: 'Grok: $grokState',
                        icon: Icons.terminal,
                        color: grokState == 'running'
                            ? GrokkerColors.mapGreen
                            : GrokkerColors.fog,
                      ),
                      const SizedBox(width: GrokkerSpacing.s8),
                      GrokkerMetaChip(
                        label: isStreaming
                            ? 'Streaming…'
                            : chat.lastActionStatus,
                        icon: isStreaming
                            ? Icons.sync
                            : Icons.check_circle_outline,
                        color: isStreaming
                            ? GrokkerColors.emberBright
                            : GrokkerColors.fog,
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
      // Comma used to open settings screen — now toggles the controls rail.
      LogicalKeySet(mod, LogicalKeyboardKey.comma): () =>
          setState(() => _inspectorVisible = !_inspectorVisible),
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
    final workspaceCubit = context.read<WorkspaceCubit>();
    final sessionCubit = context.read<SessionCubit>();
    await workspaceCubit.openFolder();
    if (!context.mounted) return;
    final ws = workspaceCubit.state.workspace;
    if (ws != null) {
      _locator.acpConnectionCubit.updateWorkspace(ws.path);
      _locator.clientRequestHandler.workspacePath = ws.path;
      if (_locator.settingsCubit.state.settings.autoCreateSession) {
        await _newSession(context, sessionCubit: sessionCubit);
      }
    }
  }

  Future<void> _newSession(
    BuildContext context, {
    SessionCubit? sessionCubit,
    WorkspaceCubit? workspaceCubit,
    SettingsCubit? settingsCubit,
  }) async {
    final sessions = sessionCubit ?? context.read<SessionCubit>();
    final workspace = workspaceCubit ?? context.read<WorkspaceCubit>();
    final settingsState = settingsCubit ?? context.read<SettingsCubit>();
    final ws = workspace.state.workspace;
    final settings = settingsState.state.settings;
    await sessions.createSession(
      workspacePath: ws?.path ?? '',
      model: settings.defaultModel,
      effort: settings.defaultEffort,
      processCommand: _locator.grokCliCubit.state.command,
    );
  }

  /// Goal and Multitask cannot run together.
  void _toggleGoalExclusive(BuildContext context, {required bool isStreaming}) {
    final goalCubit = context.read<GoalCubit>();
    final multiCubit = context.read<MultitaskCubit>();
    if (goalCubit.state.isActive) {
      goalCubit.stopGoal();
      return;
    }
    if (multiCubit.state.enabled) {
      multiCubit.disable();
    }
    final text = _composerController.text.trim();
    goalCubit.arm(text: text);
    if (text.isNotEmpty && !isStreaming) {
      unawaited(_send(context));
    }
  }

  void _toggleMultitaskExclusive(BuildContext context) {
    final goalCubit = context.read<GoalCubit>();
    final multiCubit = context.read<MultitaskCubit>();
    if (multiCubit.state.enabled) {
      multiCubit.disable();
      return;
    }
    if (goalCubit.state.isActive) {
      goalCubit.stopGoal(status: 'Goal stopped — Multitask enabled');
    }
    multiCubit.setEnabled(true);
  }

  Future<void> _send(BuildContext context) async {
    final rawText = _composerController.text.trim();
    final attachmentCubit = context.read<AttachmentCubit>();
    final chatCubit = context.read<ChatCubit>();
    final sessionCubit = context.read<SessionCubit>();
    final workspaceCubit = context.read<WorkspaceCubit>();
    final acpCubit = context.read<AcpConnectionCubit>();
    final cliCubit = context.read<GrokCliCubit>();
    final settingsCubit = context.read<SettingsCubit>();
    final goalCubit = context.read<GoalCubit>();
    final multiCubit = context.read<MultitaskCubit>();
    final attachments = attachmentCubit.state.attachments;

    // Goal-armed with empty prompt box: still allow if goal text is already set
    // (continuation is automatic; manual send re-asserts the goal).
    // Image/file-only sends are valid (empty text + attachments).
    final goalHasText = goalCubit.state.text?.trim().isNotEmpty ?? false;
    if (rawText.isEmpty && attachments.isEmpty && !goalHasText) return;

    final settings = settingsCubit.state.settings;
    final attachmentsToSend = List<AttachmentItem>.from(attachments);
    final hasAttachments = attachmentsToSend.isNotEmpty;

    // Frame prompt for Goal *or* Multitask (never both).
    // Keep a short scrollback label; only the ACP payload is framed.
    // Do NOT clear composer/attachments until framing succeeds — otherwise
    // early returns silently drop attached images.
    var text = rawText;
    var displayText = rawText;
    final goalOn = goalCubit.state.isActive && !goalCubit.state.isComplete;
    if (goalOn && multiCubit.state.enabled) {
      // Safety: Goal wins if both somehow active.
      multiCubit.disable();
    }
    if (goalOn) {
      // Capture goal text from this send if not yet set.
      if (rawText.isNotEmpty) {
        goalCubit.ensureGoalText(rawText);
      }
      if (goalCubit.state.iteration == 0) {
        var seed = rawText.isNotEmpty
            ? rawText
            : (goalCubit.state.text ?? '');
        // Image/file-only: still start goal with a sensible default seed.
        if (seed.isEmpty && hasAttachments) {
          seed = _defaultAttachmentGoalSeed(attachmentsToSend);
        }
        if (seed.isEmpty) return;
        displayText = rawText.isNotEmpty ? rawText : seed;
        text = goalCubit.frameInitialPrompt(seed);
        goalCubit.incrementIteration();
        goalCubit.markRunning();
      } else if (rawText.isEmpty && goalHasText) {
        // Manual "continue" while goal is running (optionally with new files).
        displayText = hasAttachments ? 'Continue goal + attachments' : 'Continue goal';
        text = goalCubit.buildContinuationPrompt();
        goalCubit.markRunning();
      } else if (rawText.isNotEmpty) {
        // User injected mid-goal guidance.
        displayText = rawText;
        text =
            '''
Additional guidance while pursuing the GOAL (${goalCubit.state.text}):

$rawText

Remember: when the goal is fully done, end with:
✅ Goal achieved
'''
                .trim();
        goalCubit.markRunning();
      } else if (!hasAttachments) {
        return;
      }
    } else if (multiCubit.state.enabled) {
      // Multitask framing; empty body is fine when files are attached.
      if (text.trim().isEmpty && hasAttachments) {
        text = _defaultAttachmentPrompt(attachmentsToSend);
      }
      text = multiCubit.framePrompt(text);
      if (rawText.isEmpty) {
        displayText = hasAttachments ? '' : 'Multitask';
      }
    }

    // Allow empty text when attachments are present — ChatCubit / envelope
    // builder inject "Please analyze the attached image(s)."
    if (text.trim().isEmpty && !hasAttachments) return;

    // Clear composer only after we know the send will proceed.
    _composerController.clear();
    attachmentCubit.clearUnpinned();

    final acpState = acpCubit.state;
    if (!acpState.initialized) {
      final cli = cliCubit.state;
      if (cli.found && cli.command != null) {
        await acpCubit.start(command: cli.command!, args: cli.args);
      }
    }

    var session = sessionCubit.state.activeSession;
    if (session == null) {
      await _newSession(
        context,
        sessionCubit: sessionCubit,
        workspaceCubit: workspaceCubit,
        settingsCubit: settingsCubit,
      );
      session = sessionCubit.state.activeSession;
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

    final wsState = workspaceCubit.state;

    await chatCubit.sendMessage(
      session: session,
      userText: text,
      displayText: displayText,
      workspace: wsState.workspace,
      workspaceMemory: wsState.memory,
      attachments: attachmentsToSend,
      supportsImages: supportsImages,
      supportsEmbeddedContext: supportsEmbedded,
      attachmentSection: attachmentSection,
      settings: settings,
    );
  }

  Future<void> _restartGrok(BuildContext context) async {
    final cli = context.read<GrokCliCubit>().state;
    await context.read<AcpConnectionCubit>().restart(
      command: cli.command ?? AppConstants.defaultGrokCommand,
      args: cli.args,
    );
  }

  static String _defaultAttachmentPrompt(List<AttachmentItem> attachments) {
    final images =
        attachments.where((a) => a.type == AttachmentType.image).length;
    if (images == 1) return 'Please analyze the attached image.';
    if (images > 1) return 'Please analyze the attached images.';
    if (attachments.length == 1) {
      return 'Please review the attached file: ${attachments.first.fileName}';
    }
    return 'Please review the attached files.';
  }

  static String _defaultAttachmentGoalSeed(List<AttachmentItem> attachments) {
    final images =
        attachments.where((a) => a.type == AttachmentType.image).length;
    if (images == 1) return 'Analyze the attached image thoroughly.';
    if (images > 1) return 'Analyze the attached images thoroughly.';
    return 'Review and analyze the attached files.';
  }
}
