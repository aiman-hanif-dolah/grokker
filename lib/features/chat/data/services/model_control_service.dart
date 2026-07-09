import '../../../../shared/models/app_settings.dart';
import '../../../../shared/models/grok_model.dart';
import '../../../../shared/models/thinking_effort.dart';

class ModelControlResult {
  const ModelControlResult({
    required this.controlPrompt,
    required this.cliModelLabel,
    required this.effortLabel,
    this.useSlashCommand = true,
  });

  final String controlPrompt;
  final String cliModelLabel;
  final String effortLabel;
  final bool useSlashCommand;
}

class ModelControlService {
  String resolveCliLabel(GrokModel model, AppSettings settings) {
    final custom = settings.customModelLabels[model.name];
    return custom ?? model.cliLabel;
  }

  ModelControlResult buildControl({
    required GrokModel model,
    required ThinkingEffort effort,
    required AppSettings settings,
    required bool alreadyConfirmed,
  }) {
    final cliLabel = resolveCliLabel(model, settings);
    final effortLabel = effort.cliValue;

    if (alreadyConfirmed) {
      return ModelControlResult(
        controlPrompt: '',
        cliModelLabel: cliLabel,
        effortLabel: effortLabel,
        useSlashCommand: false,
      );
    }

    final slash = '/model $cliLabel $effortLabel';
    final controlPrompt =
        'Switch to $cliLabel with $effortLabel effort for this session. '
        'Confirm only if switched.\n'
        'If supported, apply: $slash';

    return ModelControlResult(
      controlPrompt: controlPrompt,
      cliModelLabel: cliLabel,
      effortLabel: effortLabel,
    );
  }

  bool detectModelConfirmation(
    String text,
    GrokModel model,
    AppSettings settings,
  ) {
    final label = resolveCliLabel(model, settings).toLowerCase();
    final lower = text.toLowerCase();
    return lower.contains(label) &&
        (lower.contains('switched') ||
            lower.contains('confirmed') ||
            lower.contains('using'));
  }
}
