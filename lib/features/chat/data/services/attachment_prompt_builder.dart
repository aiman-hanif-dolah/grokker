import '../../../../shared/models/app_settings.dart';
import '../../../../shared/models/attachment_item.dart';
import 'prompt_envelope_builder.dart';

class AttachmentPromptBuilder {
  AttachmentPromptBuilder({PromptEnvelopeBuilder? envelopeBuilder})
    : _envelopeBuilder = envelopeBuilder ?? PromptEnvelopeBuilder();

  final PromptEnvelopeBuilder _envelopeBuilder;

  Future<List<Map<String, dynamic>>> build({
    required String text,
    required List<AttachmentItem> attachments,
    required bool supportsImages,
    required bool supportsEmbeddedContext,
    required AppSettings settings,
  }) {
    return _envelopeBuilder.buildAcpPrompt(
      text: text,
      attachments: attachments,
      supportsImages: supportsImages,
      supportsEmbeddedContext: supportsEmbeddedContext,
    );
  }
}
