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

  void Function(AppSession session)? onSessionUpdated;
  AppSession? _activeSession;
  String? _currentStreamMessageId;
  String _streamBuffer = '';
  List<ChatImageAttachment> _streamImages = [];
  bool _isGeneratingTitle = false;
  String _titleBuffer = '';
  bool _promptInFlight = false;
  bool _streamUiFinalized = false;
  Timer? _streamIdleTimer;
  static const _streamIdleTimeout = Duration(seconds: 2);

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
        onSessionUpdated?.call(workingSession);
      }

      // Append user message + streaming placeholder immediately so the UI shows it
      // without waiting for ACP session creation, attachment processing or send.
      final userImages = attachments
          .where((a) => a.type == AttachmentType.image)
          .map((a) => ChatImageAttachment(id: _uuid.v4(), path: a.path, mimeType: a.mimeType))
          .toList();
      final userMessage = ChatMessage(
        id: _uuid.v4(),
        role: ChatMessageRole.user,
        content: _userMessageLabel(
          userText: userText,
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
      onSessionUpdated?.call(workingSession);

      if (workingSession.acpSessionId == null || workingSession.acpSessionId!.isEmpty) {
        final acpSession = await _acpClient.createSession(cwd: workspace?.path);
        workingSession = workingSession.copyWith(acpSessionId: acpSession.id);
        _activeSession = workingSession;
        onSessionUpdated?.call(workingSession);
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
      unawaited(_maybeContinueGoal());
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
    } catch (e) {
      _finalizeFailedStream();
      emit(
        state.copyWith(
          isStreaming: false,
          lastActionStatus: 'Prompt failed: $e',
        ),
      );
    } finally {
      _promptInFlight = false;
      _cancelStreamIdleTimer();
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
            content: _finalizedAssistantContent(
              interrupted: true,
            ),
            status: ChatMessageStatus.failed,
            images: _streamImages,
          );
        }
        return m;
      }).toList(),
    );
    _activeSession = updated;
    _currentStreamMessageId = null;
    onSessionUpdated?.call(updated);
  }

  void cancelGeneration() {
    final session = _activeSession;
    if (session?.acpSessionId != null) {
      _acpClient.cancelSession(session!.acpSessionId!);
    }
    emit(
      state.copyWith(isStreaming: false, lastActionStatus: 'Cancelled by user'),
    );
  }

  void setModel(GrokModel model) {
    final session = _activeSession;
    if (session == null) return;
    onSessionUpdated?.call(
      session.copyWith(
        selectedModel: model,
        modelConfirmed: false,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void setEffort(ThinkingEffort effort) {
    final session = _activeSession;
    if (session == null) return;
    onSessionUpdated?.call(
      session.copyWith(
        selectedEffort: effort,
        effortConfirmed: false,
        updatedAt: DateTime.now(),
      ),
    );
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
    final current = _activeSession?.id == session.id ? _activeSession! : session;
    final updated = current.copyWith(
      title: title ?? current.title,
      titleGenerated: true,
      updatedAt: DateTime.now(),
    );
    _activeSession = updated;
    onSessionUpdated?.call(updated);
  }

  void _markTitleGenerationAttempted(AppSession session) {
    final current = _activeSession?.id == session.id ? _activeSession! : session;
    if (current.titleGenerated) return;
    final updated = current.copyWith(titleGenerated: true);
    _activeSession = updated;
    onSessionUpdated?.call(updated);
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
          _updateStreamingAssistantMessage(session);
          _scheduleStreamIdleFinalization(session);
          if (state.isStreaming && state.lastActionStatus == 'Sending prompt…') {
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
        onSessionUpdated?.call(session);
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
          onSessionUpdated?.call(session.copyWith(modelConfirmed: true));
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

    final updated = session.copyWith(
      status: AppSessionStatus.idle,
      updatedAt: DateTime.now(),
      messages: session.messages.map((m) {
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
    onSessionUpdated?.call(updated);

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

  void _updateStreamingAssistantMessage(AppSession session) {
    if (_currentStreamMessageId == null) return;
    final updated = session.copyWith(
      messages: session.messages.map((m) {
        if (m.id == _currentStreamMessageId) {
          return m.copyWith(
            content: _streamBuffer,
            images: _streamImages,
          );
        }
        return m;
      }).toList(),
    );
    _activeSession = updated;
    onSessionUpdated?.call(updated);
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
    onSessionUpdated?.call(
      session.copyWith(
        messages: [...session.messages, errorMsg],
        status: AppSessionStatus.error,
      ),
    );
  }

  @override
  Future<void> close() async {
    _cancelStreamIdleTimer();
    await _eventSub?.cancel();
    return super.close();
  }

  Future<void> _maybeContinueGoal() async {
    final goal = ServiceLocator.instance.goalCubit.state;
    if (!goal.isActive || goal.isComplete || goal.text == null) return;

    final lastMessage = _activeSession?.messages.lastOrNull;
    if (lastMessage == null || lastMessage.role != ChatMessageRole.assistant) return;

    if (lastMessage.content.contains('✅ Goal achieved')) {
      ServiceLocator.instance.goalCubit.markComplete();
      return;
    }

    ServiceLocator.instance.goalCubit.incrementIteration();
    await Future.delayed(const Duration(milliseconds: 300));
    if (_promptInFlight) return;

    await sendMessage(
      session: _activeSession!,
      userText: goal.text!,
      workspace: null,
      attachments: const [],
      supportsImages: true,
      supportsEmbeddedContext: true,
      attachmentSection: '',
      settings: ServiceLocator.instance.settingsCubit.state.settings,
    );
  }
}
