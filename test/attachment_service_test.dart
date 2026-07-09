import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/attachments/data/services/attachment_service.dart';

void main() {
  late AttachmentService service;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('grokker_test');
    service = AttachmentService(
      supportDirectoryProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('validates supported file types', () async {
    final file = File('${tempDir.path}/test.dart');
    await file.writeAsString('void main() {}');

    final item = await service.validateAndCreate(file.path);
    expect(item, isNotNull);
    expect(item!.type.name, 'code');
  });

  test('rejects unknown extensions', () async {
    final file = File('${tempDir.path}/test.xyz');
    await file.writeAsString('data');

    final item = await service.validateAndCreate(file.path);
    expect(item, isNull);
  });

  test('createFromBytes stores pasted png', () async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );

    final item = await service.createFromBytes(
      bytes: Uint8List.fromList(bytes),
      mimeType: 'image/png',
      extension: 'png',
    );

    expect(item, isNotNull);
    expect(item!.type.name, 'image');
    expect(File(item.path).existsSync(), isTrue);
  });
}
