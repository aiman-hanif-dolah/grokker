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

  test(
    'buildAcpPrompt encodes images as native image blocks even when unsupported',
    () async {
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
      expect(imageBlock['uri'], contains('shot.png'));
      expect(imageBlock['uri'], startsWith('file://'));
    },
  );

  test(
    'buildAcpPrompt encodes images as native image blocks when supported',
    () async {
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
    },
  );

  test('buildAcpPrompt embeds PDF as base64 resource blob', () async {
    final pdfBytes = utf8.encode('%PDF-1.4\nfake pdf body for test');
    final pdfPath = '${tempDir.path}/report.pdf';
    await File(pdfPath).writeAsBytes(pdfBytes);

    final blocks = await builder.buildAcpPrompt(
      text: 'summarize this pdf',
      attachments: [
        AttachmentItem(
          id: 'pdf_1',
          path: pdfPath,
          type: AttachmentType.pdf,
          fileName: 'report.pdf',
          sizeBytes: pdfBytes.length,
          mimeType: 'application/pdf',
        ),
      ],
      supportsImages: false,
      supportsEmbeddedContext: true,
    );

    final resource = blocks.firstWhere(
      (b) => b['type'] == 'resource' && (b['resource'] as Map)['blob'] != null,
    );
    final res = resource['resource'] as Map<String, dynamic>;
    expect(res['mimeType'], 'application/pdf');
    expect(res['blob'], base64Encode(pdfBytes));
    expect(res['uri'], contains('report.pdf'));

    // Also includes resource_link for path access
    expect(blocks.any((b) => b['type'] == 'resource_link'), isTrue);
  });

  test('buildAcpPrompt embeds text file content in resource', () async {
    final path = '${tempDir.path}/notes.txt';
    await File(path).writeAsString('hello from notes');

    final blocks = await builder.buildAcpPrompt(
      text: 'read notes',
      attachments: [
        AttachmentItem(
          id: 't1',
          path: path,
          type: AttachmentType.text,
          fileName: 'notes.txt',
          sizeBytes: 16,
          mimeType: 'text/plain',
        ),
      ],
      supportsImages: false,
      supportsEmbeddedContext: true,
    );

    final resource = blocks.firstWhere((b) => b['type'] == 'resource');
    final res = resource['resource'] as Map<String, dynamic>;
    expect(res['text'], contains('hello from notes'));
  });
}
