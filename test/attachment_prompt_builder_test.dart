import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/chat/data/services/prompt_envelope_builder.dart';
import 'package:grokker/shared/models/attachment_item.dart';

void main() {
  late Directory tempDir;
  late PromptEnvelopeBuilder builder;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('grokker_prompt_test');
    builder = PromptEnvelopeBuilder();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('buildAcpPrompt encodes images as native image blocks even when unsupported', () async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final imagePath = '${tempDir.path}/shot.png';
    await File(imagePath).writeAsBytes(bytes);

    final blocks = await builder.buildAcpPrompt(
      text: 'check this screenshot',
      attachments: [
        AttachmentItem(
          id: 'att_1',
          path: imagePath,
          type: AttachmentType.image,
          fileName: 'shot.png',
          sizeBytes: bytes.length,
          mimeType: 'image/png',
        ),
      ],
      supportsImages: false,
      supportsEmbeddedContext: true,
    );

    expect(blocks, hasLength(2));
    final imageBlock = blocks.last;
    expect(imageBlock['type'], 'image');
    expect(imageBlock['mimeType'], 'image/png');
    expect(imageBlock['data'], base64Encode(bytes));
    expect(imageBlock['data'], isNot(contains('/')));
    expect(imageBlock['uri'], 'file://$imagePath');
  });

  test('buildAcpPrompt encodes images as native image blocks when supported', () async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final imagePath = '${tempDir.path}/shot.png';
    await File(imagePath).writeAsBytes(bytes);

    final blocks = await builder.buildAcpPrompt(
      text: 'check this screenshot',
      attachments: [
        AttachmentItem(
          id: 'att_1',
          path: imagePath,
          type: AttachmentType.image,
          fileName: 'shot.png',
          sizeBytes: bytes.length,
          mimeType: 'image/png',
        ),
      ],
      supportsImages: true,
      supportsEmbeddedContext: false,
    );

    expect(blocks, hasLength(2));
    final imageBlock = blocks.last;
    expect(imageBlock['type'], 'image');
    expect(imageBlock['mimeType'], 'image/png');
    expect(imageBlock['data'], isNot(contains('/')));
    expect(imageBlock['data'], base64Encode(bytes));
  });
}