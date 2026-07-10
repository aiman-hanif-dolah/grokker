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
    expect(text, contains('Model requested: Composer 2.5'));
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

  test('model label mapping uses CLI ids', () {
    expect(GrokModel.composer25Fast.cliLabel, 'grok-composer-2.5-fast');
    final control = modelControl.buildControl(
      model: GrokModel.grok45,
      effort: ThinkingEffort.medium,
      settings: const AppSettings(),
      alreadyConfirmed: false,
    );
    expect(control.controlPrompt, contains('grok-4.5'));
    expect(control.controlPrompt, contains('/model grok-4.5 medium'));
  });

  test('legacy model ids migrate to latest', () {
    expect(GrokModelX.fromString('grok43')?.id, 'grok-4.5');
    expect(GrokModelX.fromString('grokBuild01')?.id, 'grok-4.5');
    expect(
      GrokModelX.fromString('composer25Fast')?.id,
      'grok-composer-2.5-fast',
    );
  });
}
