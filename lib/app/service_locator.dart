import '../features/acp/data/services/acp_client.dart';
import '../features/acp/data/services/acp_client_request_handler.dart';
import '../features/acp/data/services/grok_cli_locator_service.dart';
import '../features/acp/data/services/grok_process_service.dart';
import '../features/acp/presentation/cubit/acp_connection_cubit.dart';
import '../features/acp/presentation/cubit/grok_cli_cubit.dart';
import '../features/attachments/data/services/attachment_service.dart';
import '../features/attachments/presentation/cubit/attachment_cubit.dart';
import '../features/chat/data/services/attachment_prompt_builder.dart';
import '../features/chat/data/services/prompt_envelope_builder.dart';
import '../features/chat/data/services/generated_image_service.dart';
import '../features/chat/data/services/session_title_service.dart';
import '../features/chat/presentation/cubit/chat_cubit.dart';
import '../features/diagnostics/presentation/cubit/diagnostics_cubit.dart';
import '../features/diff_viewer/data/services/diff_service.dart';
import '../features/diff_viewer/presentation/cubit/diff_cubit.dart';
import '../features/goal/presentation/cubit/goal_cubit.dart';
import '../features/sessions/data/repositories/session_repository.dart';
import '../features/sessions/presentation/cubit/session_cubit.dart';
import '../features/settings/data/repositories/settings_repository.dart';
import '../features/settings/presentation/cubit/settings_cubit.dart';
import '../features/workspace/data/repositories/workspace_memory_repository.dart';
import '../features/workspace/data/services/workspace_memory_service.dart';
import '../features/workspace/data/services/workspace_service.dart';
import '../features/workspace/presentation/cubit/workspace_cubit.dart';
import 'cubit/app_startup_cubit.dart';

class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator instance = ServiceLocator._();

  late final SettingsRepository settingsRepository;
  late final SessionRepository sessionRepository;
  late final GrokCliLocatorService grokCliLocator;
  late final GrokProcessService grokProcessService;
  late final AcpClient acpClient;
  late final AcpClientRequestHandler clientRequestHandler;
  late final WorkspaceService workspaceService;
  late final WorkspaceMemoryRepository workspaceMemoryRepository;
  late final WorkspaceMemoryService workspaceMemoryService;
  late final AttachmentService attachmentService;
  late final DiffService diffService;
  late final PromptEnvelopeBuilder promptEnvelopeBuilder;
  late final AttachmentPromptBuilder attachmentPromptBuilder;
  late final SessionTitleService sessionTitleService;
  late final GeneratedImageService generatedImageService;

  late final SettingsCubit settingsCubit;
  late final GrokCliCubit grokCliCubit;
  late final AcpConnectionCubit acpConnectionCubit;
  late final WorkspaceCubit workspaceCubit;
  late final SessionCubit sessionCubit;
  late final ChatCubit chatCubit;
  late final AttachmentCubit attachmentCubit;
  late final DiagnosticsCubit diagnosticsCubit;
  late final DiffCubit diffCubit;
  late final GoalCubit goalCubit;
  late final AppStartupCubit appStartupCubit;

  Future<void> init() async {
    settingsRepository = SettingsRepository();
    sessionRepository = SessionRepository();
    grokCliLocator = GrokCliLocatorService();
    grokProcessService = GrokProcessService();
    acpClient = AcpClient(processService: grokProcessService);
    diffService = DiffService();
    clientRequestHandler = AcpClientRequestHandler(diffService: diffService);
    workspaceService = WorkspaceService();
    workspaceMemoryRepository = WorkspaceMemoryRepository();
    workspaceMemoryService = WorkspaceMemoryService(
      repository: workspaceMemoryRepository,
    );
    attachmentService = AttachmentService();
    promptEnvelopeBuilder = PromptEnvelopeBuilder();
    attachmentPromptBuilder = AttachmentPromptBuilder();
    sessionTitleService = SessionTitleService();
    generatedImageService = GeneratedImageService();

    settingsCubit = SettingsCubit(settingsRepository);
    grokCliCubit = GrokCliCubit(grokCliLocator);
    acpConnectionCubit = AcpConnectionCubit(
      processService: grokProcessService,
      acpClient: acpClient,
      clientRequestHandler: clientRequestHandler,
    );
    workspaceCubit = WorkspaceCubit(workspaceService, workspaceMemoryService);
    sessionCubit = SessionCubit(sessionRepository);
    chatCubit = ChatCubit(
      acpClient: acpClient,
      envelopeBuilder: promptEnvelopeBuilder,
      attachmentPromptBuilder: attachmentPromptBuilder,
      sessionTitleService: sessionTitleService,
      generatedImageService: generatedImageService,
      workspaceMemoryService: workspaceMemoryService,
    );
    attachmentCubit = AttachmentCubit(attachmentService);
    diagnosticsCubit = DiagnosticsCubit(
      processService: grokProcessService,
      acpClient: acpClient,
    );
    diffCubit = DiffCubit(diffService);
    goalCubit = GoalCubit();
    appStartupCubit = AppStartupCubit();

    chatCubit.onSessionUpdated = (session) {
      sessionCubit.updateSession(session);
    };

    await settingsCubit.load();
    await sessionCubit.load();
  }

  Future<void> dispose() async {
    await acpConnectionCubit.close();
    await chatCubit.close();
    await diagnosticsCubit.close();
    await grokProcessService.dispose();
    await acpClient.dispose();
  }
}
