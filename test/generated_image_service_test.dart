import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/chat/data/services/generated_image_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeneratedImageService', () {
    late GeneratedImageService service;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('grokker_image_test');
      service = GeneratedImageService(
        supportDirectoryProvider: () async => tempDir,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saveBase64Image writes png bytes', () async {
      const pngBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      final attachment = await service.saveBase64Image(
        sessionId: 'session_test',
        base64Data: pngBase64,
      );

      expect(File(attachment.path).existsSync(), isTrue);
      expect(attachment.mimeType, 'image/png');
    });

    test('importImageFile copies source image', () async {
      final source = File('${tempDir.path}/source.png');
      await source.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        ),
      );

      final attachment = await service.importImageFile(
        sessionId: 'session_copy',
        sourcePath: source.path,
      );

      expect(File(attachment.path).existsSync(), isTrue);
      expect(attachment.mimeType, 'image/png');
    });
  });
}