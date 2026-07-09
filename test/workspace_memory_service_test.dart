import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/workspace/data/repositories/workspace_memory_repository.dart';
import 'package:grokker/features/workspace/data/services/workspace_memory_service.dart';
import 'package:grokker/features/workspace/domain/models/workspace_memory.dart';
import 'package:grokker/shared/models/workspace_info.dart';

void main() {
  group('WorkspaceMemoryService', () {
    late Directory tempDir;
    late Directory supportDir;
    late WorkspaceMemoryService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('grokker_ws_mem');
      supportDir = Directory('${tempDir.path}/support');
      await supportDir.create(recursive: true);
      service = WorkspaceMemoryService(
        repository: WorkspaceMemoryRepository(
          supportDirectoryProvider: () async => supportDir,
        ),
        maxDepth: 3,
        maxFiles: 200,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('scans workspace and reads AGENTS.md', () async {
      final project = Directory('${tempDir.path}/demo');
      await project.create();
      await File('${project.path}/AGENTS.md').writeAsString(
        '# Agent rules\nAlways run tests.',
      );
      await Directory('${project.path}/lib').create();
      await File('${project.path}/lib/main.dart').writeAsString('void main() {}');
      await File('${project.path}/pubspec.yaml').writeAsString('name: demo');

      final info = WorkspaceInfo(
        path: project.path,
        name: 'demo',
        projectTypes: const [ProjectType.flutter],
      );

      final memory = await service.loadOrScan(
        workspacePath: project.path,
        workspaceInfo: info,
        forceRescan: true,
      );

      expect(memory.agentsMd, contains('Agent rules'));
      expect(memory.fileCount, greaterThan(0));
      expect(memory.fileTreeSummary, contains('lib/'));
      expect(memory.keyFiles, contains('AGENTS.md'));
    });

    test('uses cache when fingerprint unchanged', () async {
      final project = Directory('${tempDir.path}/cached');
      await project.create();
      await File('${project.path}/README.md').writeAsString('Hello');

      final info = WorkspaceInfo(
        path: project.path,
        name: 'cached',
        projectTypes: const [ProjectType.general],
      );

      final first = await service.loadOrScan(
        workspacePath: project.path,
        workspaceInfo: info,
        forceRescan: true,
      );

      final second = await service.loadOrScan(
        workspacePath: project.path,
        workspaceInfo: info,
      );

      expect(second.scannedAt, first.scannedAt);
      expect(await service.hasValidCache(project.path), isTrue);
    });

    test('buildPromptSection includes agents and tree', () {
      final memory = WorkspaceMemory(
        workspacePath: '/tmp/demo',
        fingerprint: 'fp',
        scannedAt: DateTime(2026, 7, 3),
        fileCount: 3,
        directoryCount: 1,
        fileTreeSummary: 'demo/\n  lib/',
        agentsMd: 'Follow AGENTS',
      );

      final section = service.buildPromptSection(memory);
      expect(section, contains('AGENTS.md'));
      expect(section, contains('Follow AGENTS'));
      expect(section, contains('Directory structure'));
    });
  });
}