import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/workspace/data/services/workspace_service.dart';
import 'package:grokker/shared/models/workspace_info.dart';

void main() {
  late WorkspaceService service;
  late Directory tempDir;

  setUp(() async {
    service = WorkspaceService();
    tempDir = await Directory.systemTemp.createTemp('grokker_ws');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('detects Flutter project', () async {
    await File('${tempDir.path}/pubspec.yaml').writeAsString('name: test\n');
    final info = await service.analyze(tempDir.path);
    expect(info.projectTypes, contains(ProjectType.flutter));
    expect(info.name, isNotEmpty);
  });
}
