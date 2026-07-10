import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/service_locator.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../shared/models/app_settings.dart';
import '../../../../shared/models/attachment_item.dart';
import '../../../../shared/models/chat_image_attachment.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../shared/models/grok_model.dart';
import '../../../../shared/models/thinking_effort.dart';
import '../../../../shared/models/workspace_info.dart';
import '../../../acp/data/services/acp_client.dart';
import '../../../acp/domain/models/acp_models.dart';
import '../../../sessions/domain/models/app_session.dart';
import '../../../workspace/data/services/workspace_memory_service.dart';
import '../../../workspace/domain/models/workspace_memory.dart';
import '../../data/services/attachment_prompt_builder.dart';
import '../../../goal/presentation/cubit/goal_cubit.dart';
import '../../data/services/generated_image_service.dart';
import '../../data/services/prompt_envelope_builder.dart';
import '../../data/services/session_title_service.dart';

class ChatState extends Equatable {
  const ChatState({
    this.isStreaming = false,
    this.lastActionStatus = 'Idle',
    this.lastError,
    this.pendingPermission,
    this.streamingMessageId,
  });

  final bool isStreaming;
  final String lastActionStatus;
  final AppError? lastError;
  final PendingPermissionRequest? pendingPermission;
  final String? streamingMessageId;

  ChatState copyWith({
    bool? isStreaming,
    String? lastActionStatus,
    AppError? lastError,
    PendingPermissionRequest? pendingPermission,
    String? streamingMessageId,
    bool clearError = false,
    bool clearPermission = false,
  }) {
    return ChatState(
      isStreaming: isStreaming ?? this.isStreaming,
      lastActionStatus: lastActionStatus ?? this.lastActionStatus,
      lastError: clearError ? null : (lastError ?? this.lastError),
      pendingPermission: clearPermission
          ? null
          : (pendingPermission ?? this.pendingPermission),
      streamingMessageId: streamingMessageId ?? this.streamingMessageId,
    );
  }

  @override
  List<Object?> get props => [
    isStreaming,
    lastActionStatus,
    lastError,
    pendingPermission,
    streamingMessageId,
  ];
}

class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required AcpClient acpClient,
    required PromptEnvelopeBuilder envelopeBuilder,
    required AttachmentPromptBuilder attachmentPromptBuilder,
    SessionTitleService? sessionTitleService,
    GeneratedImageService? generatedImageService,
    required WorkspaceMemoryService workspaceMemoryService,
    Uuid? uuid,
  }) : _acpClient = acpClient,
       _envelopeBuilder = envelopeBuilder,
       _attachmentPromptBuilder = attachmentPromptBuilder,
       _sessionTitleService = sessionTitleService ?? SessionTitleService(),
       _generatedImageService =
           generatedImageService ?? GeneratedImageService(),
       _workspaceMemoryService = workspaceMemoryService,
       _uuid = uuid ?? const Uuid(),
       super(const ChatState()) {
    _eventSub = _acpClient.events.listen(_onAcpEvent);
  }

  final AcpClient _acpClient;
  final PromptEnvelopeBuilder _envelopeBuilder;
  final AttachmentPromptBuilder _attachmentPromptBuilder;
  final SessionTitleService _sessionTitleService;
  final GeneratedImageService _generatedImageService;
  final WorkspaceMemoryService _workspaceMemoryService;
  final Uuid _uuid;
  StreamSubscription<AcpEvent>? _eventSub;

  /// Session UI + optional disk. Streaming tokens use [persist]: false.
  void Function(AppSession session, {bool persist})? onSessionUpdated;
  AppSession? _activeSession;
  String? _currentStreamMessageId;
  String _streamBuffer = '';
  List<ChatImageAttachment> _streamImages = [];
  bool _isGeneratingTitle = false;
  String _titleBuffer = '';
  bool _promptInFlight = false;
  bool _streamUiFinalized = false;
  Timer? _streamIdleTimer;
  Timer? _streamUiThrottle;
  bool _streamUiDirty = false;
  static const _streamIdleTimeout = Duration(seconds: 2);
  static const _streamUiThrottleInterval = Duration(milliseconds: 33);

  void _notifySession(AppSession session, {bool persist = true}) {
    onSessionUpdated?.call(session, persist: persist);
  }

  void setActiveSession(AppSession? session) {
    if (session == null) {
      _activeSession = null;
      return;
    }
    if (_activeSession?.id == session.id) {
      _activeSession = session;
      _maybeGenerateTitleForExistingSession(session);
      return;
    }
    _activeSession = session;
    _currentStreamMessageId = null;
    _streamBuffer = '';
    _streamImages = [];
    emit(const ChatState());
    _maybeGenerateTitleForExistingSession(session);
  }

  void _maybeGenerateTitleForExistingSession(AppSession session) {
    if (session.titleGenerated || session.acpSessionId == null) return;
    if (!_sessionTitleService.isPlaceholderTitle(session.title)) return;
    if (!session.messages.any((m) => m.role == ChatMessageRole.user)) return;
    if (state.isStreaming || _promptInFlight || _isGeneratingTitle) return;
    unawaited(_maybeGenerateTitle(session));
  }

  Future<void> sendMessage({
    required AppSession session,
    required String userText,

    /// Optional short label for scrollback (e.g. raw goal text while
    /// [userText] carries the framed ACP payload).
    String? displayText,
    required WorkspaceInfo? workspace,
    WorkspaceMemory? workspaceMemory,
    required List<AttachmentItem> attachments,
    required bool supportsImages,
    required bool supportsEmbeddedContext,
    required String attachmentSection,
    required AppSettings settings,
  }) async {
    if (userText.trim().isEmpty && attachments.isEmpty) return;
    if (_promptInFlight || _isGeneratingTitle) return;

    _activeSession = session;
    _promptInFlight = true;
    _streamUiFinalized = false;
    _cancelStreamIdleTimer();
    emit(
      state.copyWith(
        isStreaming: true,
        lastActionStatus: 'Sending prompt…',
        clearError: true,
      ),
    );

    try {
      var workingSession = session.copyWith(
        messages: session.messages
            .where((m) => m.role != ChatMessageRole.error)
            .toList(),
      );
      if (workingSession.messages.length != session.messages.length) {
        _notifySession(workingSession, persist: false);
      }

      // Append user message + streaming placeholder immediately so the UI shows it
      // without waiting for ACP session creation, attachment processing or send.
      final userImages = attachments
          .where((a) => a.type == AttachmentType.image)
          .map(
            (a) => ChatImageAttachment(
              id: _uuid.v4(),
              path: a.path,
              mimeType: a.mimeType,
            ),
          )
          .toList();
      final scrollbackText = (displayText ?? userText).trim().isNotEmpty
          ? (displayText ?? userText)
          : userText;
      final userMessage = ChatMessage(
        id: _uuid.v4(),
        role: ChatMessageRole.user,
        content: _userMessageLabel(
          userText: scrollbackText,
          attachments: attachments,
        ),
        createdAt: DateTime.now(),
        status: ChatMessageStatus.completed,
        images: userImages,
      );

      final assistantPlaceholder = ChatMessage(
        id: _uuid.v4(),
        role: ChatMessageRole.assistant,
        content: '',
        createdAt: DateTime.now(),
        status: ChatMessageStatus.streaming,
      );

      _currentStreamMessageId = assistantPlaceholder.id;
      _streamBuffer = '';
      _streamImages = [];

      workingSession = workingSession.copyWith(
        messages: [
          ...workingSession.messages,
          userMessage,
          assistantPlaceholder,
        ],
        status: AppSessionStatus.streaming,
        updatedAt: DateTime.now(),
      );
      _activeSession = workingSession;
      _notifySession(workingSession, persist: false);

      if (workingSession.acpSessionId == null ||
          workingSession.acpSessionId!.isEmpty) {
        final acpSession = await _acpClient.createSession(cwd: workspace?.path);
        workingSession = workingSession.copyWith(acpSessionId: acpSession.id);
        _activeSession = workingSession;
        _notifySession(workingSession, persist: true);
      }

      final memorySection = workspaceMemory == null
          ? null
          : _workspaceMemoryService.buildPromptSection(
              workspaceMemory,
              info: workspace,
            );

      final envelope = _envelopeBuilder.buildTextEnvelope(
        userMessage: userText,
        workspace: workspace,
        model: workingSession.selectedModel,
        effort: workingSession.selectedEffort,
        attachments: attachments,
        approvalMode: settings.approvalMode,
        attachmentSection: attachmentSection.isNotEmpty
            ? attachmentSection
            : null,
        workspaceMemorySection: memorySection,
      );

      final promptBlocks = await _attachmentPromptBuilder.build(
        text: envelope,
        attachments: attachments,
        supportsImages: supportsImages,
        supportsEmbeddedContext: supportsEmbeddedContext,
        settings: settings,
      );

      _acpClient.cancelSession(workingSession.acpSessionId!);
      await _acpClient.sendPrompt(
        sessionId: workingSession.acpSessionId!,
        prompt: promptBlocks,
      );

      _finalizeSuccessfulStream(
        workingSession,
        lastActionStatus: 'Response completed',
      );
      workingSession = _activeSession ?? workingSession;

      unawaited(_maybeGenerateTitle(workingSession));
    } on AppError catch (e) {
      _finalizeFailedStream();
      _appendErrorMessage(e);
      emit(
        state.copyWith(
          isStreaming: false,
          lastError: e,
          lastActionStatus: 'Prompt failed',
        ),
      );
      ServiceLocator.instance.goalCubit.markFailed(
        'Goal paused: prompt failed',
      );
    } catch (e) {
      _finalizeFailedStream();
      emit(
        state.copyWith(
          isStreaming: false,
          lastActionStatus: 'Prompt failed: $e',
        ),
      );
      ServiceLocator.instance.goalCubit.markFailed('Goal paused: $e');
    } finally {
      _promptInFlight = false;
      _cancelStreamIdleTimer();
      // Always schedule after the turn fully clears in-flight state.
      unawaited(Future<void>.delayed(Duration.zero, _maybeContinueGoal));
    }
  }

  void _finalizeFailedStream() {
    final session = _activeSession;
    if (session == null || _currentStreamMessageId == null) return;
    final updated = session.copyWith(
      status: AppSessionStatus.error,
      messages: session.messages.map((m) {
        if (m.id == _currentStreamMessageId &&
            m.status == ChatMessageStatus.streaming) {
          return m.copyWith(
            content: _finalizedAssistantContent(interrupted: true),
            status: ChatMessageStatus.failed,
            images: _streamImages,
          );
        }
        return m;
      }).toList(),
    );
    _activeSession = updated;
    _currentStreamMessageId = null;
    _cancelStreamUiThrottle(flush: false);
    _notifySession(updated, persist: true);
  }

  void cancelGeneration() {
    final session = _activeSession;
    if (session?.acpSessionId != null) {
      _acpClient.cancelSession(session!.acpSessionId!);
    }
    _flushStreamUi(force: true);
    if (session != null && _currentStreamMessageId != null) {
      final updated = session.copyWith(
        status: AppSessionStatus.cancelled,
        messages: session.messages.map((m) {
          if (m.id == _currentStreamMessageId &&
              m.status == ChatMessageStatus.streaming) {
            return m.copyWith(
              content: _finalizedAssistantContent(interrupted: true),
              status: ChatMessageStatus.cancelled,
              images: _streamImages,
            );
          }
          return m;
        }).toList(),
      );
      _activeSession = updated;
      _currentStreamMessageId = null;
      _streamUiFinalized = true;
      _notifySession(updated, persist: true);
    }
    emit(
      state.copyWith(isStreaming: false, lastActionStatus: 'Cancelled by user'),
    );
  }

  void setModel(GrokModel model) {
    final session = _activeSession;
    if (session == null) return;
    final updated = session.copyWith(
      selectedModel: model,
      modelConfirmed: false,
      updatedAt: DateTime.now(),
    );
    _activeSession = updated;
    _notifySession(updated, persist: true);
  }

  void setEffort(ThinkingEffort effort) {
    final session = _activeSession;
    if (session == null) return;
    final updated = session.copyWith(
      selectedEffort: effort,
      effortConfirmed: false,
      updatedAt: DateTime.now(),
    );
    _activeSession = updated;
    _notifySession(updated, persist: true);
  }

  void respondToPermission(bool approved) {
    emit(state.copyWith(clearPermission: true));
    emit(
      state.copyWith(
        lastActionStatus: approved ? 'Permission granted' : 'Permission denied',
      ),
    );
  }

  Future<void> _maybeGenerateTitle(AppSession session) async {
    if (session.titleGenerated || session.acpSessionId == null) return;
    if (!_sessionTitleService.isPlaceholderTitle(session.title)) return;

    final userMessages = session.messages
        .where((m) => m.role == ChatMessageRole.user)
        .toList();
    if (userMessages.isEmpty) return;

    final firstUser = userMessages.first;
    final assistantReply = session.messages
        .where((m) => m.role == ChatMessageRole.assistant)
        .lastOrNull
        ?.content;

    await _generateTitle(
      session: session,
      userMessage: firstUser.content,
      assistantPreview: assistantReply,
    );
  }

  Future<void> _generateTitle({
    required AppSession session,
    required String userMessage,
    String? assistantPreview,
  }) async {
    if (_isGeneratingTitle) return;
    _isGeneratingTitle = true;
    _titleBuffer = '';

    try {
      final promptText = _sessionTitleService.buildTitlePrompt(
        userMessage: userMessage,
        assistantPreview: assistantPreview,
      );
      await _acpClient.sendPrompt(
        sessionId: session.acpSessionId!,
        prompt: [
          {'type': 'text', 'text': promptText},
        ],
        timeout: const Duration(seconds: 45),
      );

      final title = _sessionTitleService.parseTitle(_titleBuffer);
      _applyGeneratedTitle(session, title);
    } catch (_) {
      _markTitleGenerationAttempted(session);
    } finally {
      _isGeneratingTitle = false;
      _titleBuffer = '';
    }
  }

  void _applyGeneratedTitle(AppSession session, String? title) {
    final current = _activeSession?.id == session.id
        ? _activeSession!
        : session;
    final updated = current.copyWith(
      title: title ?? current.title,
      titleGenerated: true,
      updatedAt: DateTime.now(),
    );
    _activeSession = updated;
    _notifySession(updated, persist: true);
  }

  void _markTitleGenerationAttempted(AppSession session) {
    final current = _activeSession?.id == session.id
        ? _activeSession!
        : session;
    if (current.titleGenerated) return;
    final updated = current.copyWith(titleGenerated: true);
    _activeSession = updated;
    _notifySession(updated, persist: true);
  }

  void _onAcpEvent(AcpEvent event) {
    if (_isGeneratingTitle) {
      if (event.type == AcpEventType.assistantTextChunk && event.text != null) {
        _titleBuffer += event.text!;
      }
      return;
    }

    var session = _activeSession;
    if (session == null) return;

    switch (event.type) {
      case AcpEventType.promptTurnCompleted:
        if (_promptInFlight && state.isStreaming) {
          _finalizeSuccessfulStream(
            session,
            lastActionStatus: 'Response completed',
          );
        }
      case AcpEventType.assistantTextChunk:
        if (event.text != null) {
          _streamBuffer += event.text!;
          _scheduleStreamingUiFlush(session);
          _scheduleStreamIdleFinalization(session);
          if (state.isStreaming &&
              state.lastActionStatus == 'Sending prompt…') {
            emit(state.copyWith(lastActionStatus: 'Streaming…'));
          }
        }
      case AcpEventType.assistantImageChunk:
        unawaited(_handleAssistantImageChunk(event));
      case AcpEventType.toolImageCompleted:
        unawaited(_handleToolImageCompleted(event));
      case AcpEventType.toolStarted:
      case AcpEventType.toolCompleted:
      case AcpEventType.toolFailed:
        final toolMsg = ChatMessage(
          id: _uuid.v4(),
          role: ChatMessageRole.tool,
          content:
              '${event.title ?? event.toolCallId ?? 'Tool'}: ${event.status ?? event.type.name}',
          createdAt: DateTime.now(),
          toolCallId: event.toolCallId,
          title: event.title,
        );
        session = session.copyWith(
          messages: [...session.messages, toolMsg],
          rawEventCount: session.rawEventCount + 1,
        );
        _activeSession = session;
        _notifySession(session, persist: false);
        emit(
          state.copyWith(
            lastActionStatus: 'Tool: ${event.title ?? event.status}',
          ),
        );
      case AcpEventType.permissionRequested:
        emit(
          state.copyWith(
            pendingPermission: PendingPermissionRequest(
              id: _uuid.v4(),
              toolCallId: event.toolCallId ?? '',
              title: event.title ?? 'Permission required',
              description: event.rawPayload?.toString() ?? '',
            ),
          ),
        );
      case AcpEventType.modelChanged:
        if (event.text != null) {
          _notifySession(session.copyWith(modelConfirmed: true), persist: true);
        }
      case AcpEventType.sessionError:
        emit(state.copyWith(lastActionStatus: 'Session error'));
      default:
        break;
    }
  }

  void _finalizeSuccessfulStream(
    AppSession session, {
    required String lastActionStatus,
  }) {
    if (_streamUiFinalized || _currentStreamMessageId == null) return;
    _streamUiFinalized = true;
    _cancelStreamIdleTimer();
    _cancelStreamUiThrottle(flush: false);

    final base = _activeSession ?? session;
    final updated = base.copyWith(
      status: AppSessionStatus.idle,
      updatedAt: DateTime.now(),
      messages: base.messages.map((m) {
        if (m.id == _currentStreamMessageId) {
          return m.copyWith(
            content: _finalizedAssistantContent(),
            status: ChatMessageStatus.completed,
            images: _streamImages,
          );
        }
        return m;
      }).toList(),
    );
    _activeSession = updated;
    _currentStreamMessageId = null;
    _notifySession(updated, persist: true);

    emit(
      state.copyWith(
        isStreaming: false,
        lastActionStatus: lastActionStatus,
        streamingMessageId: null,
      ),
    );
  }

  void _scheduleStreamIdleFinalization(AppSession session) {
    if (!state.isStreaming || _streamUiFinalized) return;
    _streamIdleTimer?.cancel();
    _streamIdleTimer = Timer(_streamIdleTimeout, () {
      if (!state.isStreaming || _streamUiFinalized) return;
      if (_streamBuffer.isEmpty && _streamImages.isEmpty) return;
      _finalizeSuccessfulStream(
        _activeSession ?? session,
        lastActionStatus: 'Response completed',
      );
    });
  }

  void _cancelStreamIdleTimer() {
    _streamIdleTimer?.cancel();
    _streamIdleTimer = null;
  }

  String _userMessageLabel({
    required String userText,
    required List<AttachmentItem> attachments,
  }) {
    final trimmed = userText.trim();
    if (trimmed.isNotEmpty) return trimmed;

    final imageCount = attachments
        .where((a) => a.type == AttachmentType.image)
        .length;
    if (imageCount == 1) return '[Image attached]';
    if (imageCount > 1) return '[$imageCount images attached]';
    if (attachments.isNotEmpty) return '[${attachments.length} files attached]';
    return trimmed;
  }

  String _finalizedAssistantContent({bool interrupted = false}) {
    if (_streamBuffer.isNotEmpty) return _streamBuffer;
    if (_streamImages.isNotEmpty) return '';
    return interrupted ? '(response interrupted)' : '(empty response)';
  }

  void _scheduleStreamingUiFlush(AppSession session) {
    _streamUiDirty = true;
    _activeSession = session;
    if (_streamUiThrottle?.isActive ?? false) return;
    _streamUiThrottle = Timer(_streamUiThrottleInterval, () {
      _flushStreamUi();
    });
  }

  void _flushStreamUi({bool force = false}) {
    if (!_streamUiDirty && !force) return;
    final session = _activeSession;
    if (session == null || _currentStreamMessageId == null) {
      _streamUiDirty = false;
      return;
    }
    _streamUiDirty = false;
    final updated = session.copyWith(
      messages: session.messages.map((m) {
        if (m.id == _currentStreamMessageId) {
          return m.copyWith(content: _streamBuffer, images: _streamImages);
        }
        return m;
      }).toList(),
    );
    _activeSession = updated;
    // Never disk-write mid-stream.
    _notifySession(updated, persist: false);
  }

  void _cancelStreamUiThrottle({required bool flush}) {
    _streamUiThrottle?.cancel();
    _streamUiThrottle = null;
    if (flush) _flushStreamUi(force: true);
  }

  void _updateStreamingAssistantMessage(AppSession session) {
    _scheduleStreamingUiFlush(session);
    _flushStreamUi(force: true);
  }

  Future<void> _handleAssistantImageChunk(AcpEvent event) async {
    final session = _activeSession;
    if (session == null || _currentStreamMessageId == null) return;
    if (event.imageData == null && event.imagePath == null) return;

    try {
      final attachment = await _persistImageEvent(
        sessionId: session.id,
        imageData: event.imageData,
        imagePath: event.imagePath,
        mimeType: event.imageMimeType,
      );
      _streamImages = [..._streamImages, attachment];
      _updateStreamingAssistantMessage(session);
      _scheduleStreamIdleFinalization(session);
      if (state.isStreaming) {
        emit(state.copyWith(lastActionStatus: 'Image received'));
      }
    } catch (_) {
      // Keep streaming even if one image fails to persist.
    }
  }

  Future<void> _handleToolImageCompleted(AcpEvent event) async {
    final session = _activeSession;
    if (session == null || _currentStreamMessageId == null) return;
    if (event.imageData == null && event.imagePath == null) return;

    try {
      final attachment = await _persistImageEvent(
        sessionId: session.id,
        imageData: event.imageData,
        imagePath: event.imagePath,
        mimeType: event.imageMimeType,
      );
      _streamImages = [..._streamImages, attachment];
      _updateStreamingAssistantMessage(session);
      _scheduleStreamIdleFinalization(session);
      emit(state.copyWith(lastActionStatus: 'Generated image'));
    } catch (_) {
      // Ignore failed image persistence.
    }
  }

  Future<ChatImageAttachment> _persistImageEvent({
    required String sessionId,
    String? imageData,
    String? imagePath,
    String? mimeType,
  }) async {
    if (imagePath != null && imagePath.isNotEmpty) {
      return _generatedImageService.importImageFile(
        sessionId: sessionId,
        sourcePath: imagePath,
      );
    }
    return _generatedImageService.saveBase64Image(
      sessionId: sessionId,
      base64Data: imageData!,
      mimeType: mimeType,
    );
  }

  void _appendErrorMessage(AppError error) {
    final session = _activeSession;
    if (session == null) return;
    final errorMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatMessageRole.error,
      content: '${error.title}\n${error.message}\n${error.suggestedFix}',
      createdAt: DateTime.now(),
      status: ChatMessageStatus.failed,
    );
    final updated = session.copyWith(
      messages: [...session.messages, errorMsg],
      status: AppSessionStatus.error,
    );
    _activeSession = updated;
    _notifySession(updated, persist: true);
  }

  @override
  Future<void> close() async {
    _cancelStreamIdleTimer();
    _cancelStreamUiThrottle(flush: false);
    await _eventSub?.cancel();
    return super.close();
  }

  Future<void> _maybeContinueGoal() async {
    final locator = ServiceLocator.instance;
    final goalCubit = locator.goalCubit;

    if (_promptInFlight || state.isStreaming) return;
    if (_activeSession == null) return;

    if (!goalCubit.canContinue) {
      if (goalCubit.state.isActive &&
          goalCubit.state.iteration >= goalCubit.state.maxIterations) {
        goalCubit.markFailed(
          'Stopped: reached max iterations (${goalCubit.state.maxIterations})',
        );
      }
      unawaited(_maybeRunNextMultitask());
      return;
    }

    // Prefer last *assistant* message — tools often append after it.
    final lastAssistant = _lastAssistantMessage(_activeSession!);
    final content = lastAssistant?.content ?? '';

    if (content.trim().isNotEmpty &&
        GoalCubit.responseSignalsComplete(content)) {
      goalCubit.markComplete();
      unawaited(_maybeRunNextMultitask());
      return;
    }

    // Avoid tight loops on empty replies.
    if (content.trim().isEmpty && goalCubit.state.iteration > 0) {
      // Still continue once more — tools-only turns are valid progress.
    }

    // Budget check *before* increment so we don't skip the last allowed step.
    if (goalCubit.state.iteration >= goalCubit.state.maxIterations) {
      goalCubit.markFailed(
        'Stopped: reached max iterations (${goalCubit.state.maxIterations})',
      );
      return;
    }

    goalCubit.incrementIteration();
    await Future.delayed(const Duration(milliseconds: 400));
    if (_promptInFlight || state.isStreaming || _activeSession == null) {
      return;
    }
    // User may have stopped during the delay.
    if (!goalCubit.state.isActive || goalCubit.state.isComplete) return;

    final ws = locator.workspaceCubit.state;
    final caps =
        _acpClient.agentCapabilities?['promptCapabilities']
            as Map<String, dynamic>?;
    final supportsImages = caps?['image'] == true;
    final supportsEmbedded = caps?['embeddedContext'] == true;

    try {
      await sendMessage(
        session: _activeSession!,
        userText: goalCubit.buildContinuationPrompt(),
        workspace: ws.workspace,
        workspaceMemory: ws.memory,
        attachments: const [],
        supportsImages: supportsImages,
        supportsEmbeddedContext: supportsEmbedded,
        attachmentSection: '',
        settings: locator.settingsCubit.state.settings,
      );
    } catch (e) {
      goalCubit.markFailed('Goal paused: $e');
    }
  }

  ChatMessage? _lastAssistantMessage(AppSession session) {
    for (var i = session.messages.length - 1; i >= 0; i--) {
      final m = session.messages[i];
      if (m.role == ChatMessageRole.assistant) return m;
    }
    return null;
  }

  Future<void> _maybeRunNextMultitask() async {
    final locator = ServiceLocator.instance;
    final multi = locator.multitaskCubit;
    if (multi.state.queuedCount == 0) return;
    if (_promptInFlight || state.isStreaming) return;
    // Never interleave with Goal autopilot.
    if (locator.goalCubit.state.isActive) return;
    if (!multi.state.enabled && multi.state.queuedCount > 0) {
      // Queue can still run when Multitask chip is on; if disabled, skip auto.
      // Allow Run queue only when enabled.
    }
    if (!multi.state.enabled) return;

    final next = multi.markNextRunning();
    if (next == null || _activeSession == null) return;

    final ws = locator.workspaceCubit.state;
    final framed = multi.framePrompt(next.prompt);
    try {
      await sendMessage(
        session: _activeSession!,
        userText: framed,
        workspace: ws.workspace,
        workspaceMemory: ws.memory,
        attachments: const [],
        supportsImages: true,
        supportsEmbeddedContext: true,
        attachmentSection: '',
        settings: locator.settingsCubit.state.settings,
      );
      multi.markDone(next.id);
      // Next queue item is picked up via _maybeContinueGoal → _maybeRunNextMultitask.
    } catch (e) {
      multi.markFailed(next.id, e.toString());
    }
  }

  /// Call after a successful send to kick queued multitask work.
  void notifyTurnIdle() {
    if (!_promptInFlight && !state.isStreaming) {
      unawaited(_maybeRunNextMultitask());
    }
  }

  /// Public entry to drain the multitask queue (Controls → Run queue).
  Future<void> runNextMultitask() => _maybeRunNextMultitask();
}
