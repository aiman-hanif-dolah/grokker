import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/attachments/data/services/attachment_service.dart';
import 'package:grokker/features/attachments/data/services/drop_item_resolver.dart';

void main() {
  late Directory tempDir;
  late AttachmentService service;
  late DropItemResolver resolver;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('grokker_drop_test');
    service = AttachmentService(supportDirectoryProvider: () async => tempDir);
    resolver = DropItemResolver(service);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('resolves dropped file paths', () async {
    final file = File('${tempDir.path}/notes.md');
    await file.writeAsString('# hello');

    final attachments = await resolver.resolve([DropItemFile(file.path)]);

    expect(attachments, hasLength(1));
    expect(attachments.first.fileName, 'notes.md');
  });

  test('stages dropped bytes without a usable path', () async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );

    final attachments = await resolver.resolve([
      DropItemFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'image/png',
        name: 'drag.png',
      ),
    ]);

    expect(attachments, hasLength(1));
    expect(attachments.first.type.name, 'image');
    expect(File(attachments.first.path).existsSync(), isTrue);
  });
}
