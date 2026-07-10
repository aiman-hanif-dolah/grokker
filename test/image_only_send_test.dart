import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/chat/data/services/prompt_envelope_builder.dart';
import 'package:grokker/shared/models/approval_mode.dart';
import 'package:grokker/shared/models/attachment_item.dart';
import 'package:grokker/shared/models/grok_model.dart';
import 'package:grokker/shared/models/thinking_effort.dart';

void main() {
  late Directory tempDir;
  late PromptEnvelopeBuilder builder;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('grokker_img_only');
    builder = PromptEnvelopeBuilder();
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('empty user text + image still builds analyzable envelope and image block',
      () async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final imagePath = '${tempDir.path}/solo.png';
    await File(imagePath).writeAsBytes(bytes);
    final attachment = AttachmentItem(
      id: 'img1',
      path: imagePath,
      type: AttachmentType.image,
      fileName: 'solo.png',
      sizeBytes: bytes.length,
      mimeType: 'image/png',
    );

    final envelope = builder.buildTextEnvelope(
      userMessage: '',
      workspace: null,
      model: GrokModel.grok45,
      effort: ThinkingEffort.auto,
      attachments: [attachment],
      approvalMode: ApprovalMode.askEveryTime,
    );
    expect(envelope, contains('Please analyze the attached image.'));

    final blocks = await builder.buildAcpPrompt(
      text: envelope,
      attachments: [attachment],
      supportsImages: true,
      supportsEmbeddedContext: false,
    );
    expect(blocks.any((b) => b['type'] == 'image'), isTrue);
    final image = blocks.firstWhere((b) => b['type'] == 'image');
    expect(image['data'], base64Encode(bytes));
    expect(image['mimeType'], 'image/png');
  });
}
