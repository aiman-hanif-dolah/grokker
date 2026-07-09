import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/chat/data/services/model_control_service.dart';
import 'package:grokker/features/chat/data/services/prompt_envelope_builder.dart';
import 'package:grokker/shared/models/app_settings.dart';
import 'package:grokker/shared/models/approval_mode.dart';
import 'package:grokker/shared/models/grok_model.dart';
import 'package:grokker/shared/models/thinking_effort.dart';
import 'package:grokker/shared/models/workspace_info.dart';

void main() {
  final builder = PromptEnvelopeBuilder();
  final modelControl = ModelControlService();

  test('prompt envelope includes workspace and model', () {
    const workspace = WorkspaceInfo(
      path: '/projects/demo',
      name: 'demo',
      projectTypes: [ProjectType.flutter],
      gitBranch: 'main',
      isGitRepo: true,
    );

    final text = builder.buildTextEnvelope(
      userMessage: 'Fix the bug',
      workspace: workspace,
      model: GrokModel.composer25Fast,
      effort: ThinkingEffort.high,
      attachments: const [],
      approvalMode: ApprovalMode.askEveryTime,
    );

    expect(text, contains('Workspace: /projects/demo'));
    expect(text, contains('Model requested: Composer 2.5 Fast'));
    expect(text, contains('Thinking effort requested: High'));
    expect(text, contains('Fix the bug'));
  });

  test('prompt envelope includes workspace memory section', () {
    final text = builder.buildTextEnvelope(
      userMessage: 'Explain this repo',
      workspace: const WorkspaceInfo(
        path: '/projects/demo',
        name: 'demo',
        projectTypes: [ProjectType.flutter],
      ),
      model: GrokModel.composer25Fast,
      effort: ThinkingEffort.low,
      attachments: const [],
      approvalMode: ApprovalMode.autoApproveReads,
      workspaceMemorySection: 'AGENTS.md: be careful',
    );

    expect(text, contains('<workspace_context>'));
    expect(text, contains('AGENTS.md: be careful'));
    expect(text, contains('Explain this repo'));
  });

  test('model label mapping', () {
    expect(GrokModel.composer25Fast.cliLabel, 'Composer 2.5');
    final control = modelControl.buildControl(
      model: GrokModel.grok43,
      effort: ThinkingEffort.medium,
      settings: const AppSettings(),
      alreadyConfirmed: false,
    );
    expect(control.controlPrompt, contains('Grok 4.3'));
    expect(control.controlPrompt, contains('/model Grok 4.3 medium'));
  });
}
