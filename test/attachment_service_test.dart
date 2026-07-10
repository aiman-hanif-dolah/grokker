import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/attachments/data/services/attachment_service.dart';
import 'package:grokker/shared/models/attachment_item.dart';

void main() {
  late AttachmentService service;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('grokker_test');
    service = AttachmentService(supportDirectoryProvider: () async => tempDir);
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

  test('accepts unknown extensions as binary', () async {
    final file = File('${tempDir.path}/test.xyz');
    await file.writeAsString('data');

    final item = await service.validateAndCreate(file.path);
    expect(item, isNotNull);
    expect(item!.type, AttachmentType.binary);
  });

  test('accepts pdf files', () async {
    final file = File('${tempDir.path}/doc.pdf');
    // Minimal PDF header bytes
    await file.writeAsBytes(utf8.encode('%PDF-1.4\n%fake pdf content'));

    final item = await service.validateAndCreate(file.path);
    expect(item, isNotNull);
    expect(item!.type, AttachmentType.pdf);
    expect(item.mimeType, 'application/pdf');
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
