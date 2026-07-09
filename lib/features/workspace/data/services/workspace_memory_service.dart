import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../shared/models/workspace_info.dart';
import '../../domain/models/workspace_memory.dart';
import '../repositories/workspace_memory_repository.dart';

class WorkspaceMemoryService {
  WorkspaceMemoryService({
    required WorkspaceMemoryRepository repository,
    this.maxDepth = 4,
    this.maxFiles = 2500,
    this.maxReadBytes = 65536,
    this.maxTreeChars = 24000,
    this.maxPromptChars = 48000,
  }) : _repository = repository;

  final WorkspaceMemoryRepository _repository;
  final int maxDepth;
  final int maxFiles;
  final int maxReadBytes;
  final int maxTreeChars;
  final int maxPromptChars;

  static const _skipDirNames = {
    '.git',
    '.dart_tool',
    '.idea',
    '.vscode',
    '.gradle',
    '.pub-cache',
    'node_modules',
    'build',
    'dist',
    'target',
    'Pods',
    'DerivedData',
    '__pycache__',
    '.symlinks',
    'coverage',
    '.grok',
    'vendor',
    '.next',
    '.nuxt',
    'out',
  };

  static const _keyFileNames = {
    'AGENTS.md',
    'agents.md',
    'README.md',
    'readme.md',
    'pubspec.yaml',
    'package.json',
    'pyproject.toml',
    'Cargo.toml',
    'go.mod',
    'Makefile',
    'Dockerfile',
    '.cursorrules',
    'CLAUDE.md',
    'DESIGN.md',
  };

  Future<bool> hasValidCache(String workspacePath) async {
    final absolute = p.normalize(p.absolute(workspacePath));
    final cached = await _repository.load(absolute);
    if (cached == null) return false;
    final fingerprint = await _computeFingerprint(absolute);
    return cached.fingerprint == fingerprint;
  }

  Future<WorkspaceMemory> loadOrScan({
    required String workspacePath,
    required WorkspaceInfo workspaceInfo,
    bool forceRescan = false,
  }) async {
    final absolute = p.normalize(p.absolute(workspacePath));
    final fingerprint = await _computeFingerprint(absolute);

    if (!forceRescan) {
      final cached = await _repository.load(absolute);
      if (cached != null && cached.fingerprint == fingerprint) {
        return cached;
      }
    }

    final memory = await _scan(
      absolute: absolute,
      fingerprint: fingerprint,
      workspaceInfo: workspaceInfo,
    );
    await _repository.save(memory);
    return memory;
  }

  Future<WorkspaceMemory> refresh({
    required String workspacePath,
    required WorkspaceInfo workspaceInfo,
  }) {
    return loadOrScan(
      workspacePath: workspacePath,
      workspaceInfo: workspaceInfo,
      forceRescan: true,
    );
  }

  Future<String> _computeFingerprint(String absolute) async {
    final signals = <String>[];
    final root = Directory(absolute);
    if (await root.exists()) {
      final stat = await root.stat();
      signals.add('root:${stat.modified.millisecondsSinceEpoch}');
    }

    for (final name in _keyFileNames) {
      final file = File(p.join(absolute, name));
      if (await file.exists()) {
        final stat = await file.stat();
        signals.add('$name:${stat.modified.millisecondsSinceEpoch}:${stat.size}');
      }
    }

    var topLevelCount = 0;
    await for (final entity in root.list(followLinks: false)) {
      topLevelCount++;
      if (topLevelCount > 200) break;
      final stat = await entity.stat();
      signals.add(
        'top:${p.basename(entity.path)}:${stat.modified.millisecondsSinceEpoch}',
      );
    }
    signals.add('topCount:$topLevelCount');

    return signals.join('|');
  }

  Future<WorkspaceMemory> _scan({
    required String absolute,
    required String fingerprint,
    required WorkspaceInfo workspaceInfo,
  }) async {
    final treeBuffer = StringBuffer();
    var fileCount = 0;
    var dirCount = 0;
    var treeTruncated = false;

    final rootName = p.basename(absolute);
    treeBuffer.writeln('$rootName/');

    await _walkTree(
      directory: Directory(absolute),
      depth: 0,
      prefix: '',
      treeBuffer: treeBuffer,
      fileCount: () => fileCount,
      setFileCount: (v) => fileCount = v,
      dirCount: () => dirCount,
      setDirCount: (v) => dirCount = v,
      onTruncated: () => treeTruncated = true,
    );

    var treeSummary = treeBuffer.toString().trimRight();
    if (treeSummary.length > maxTreeChars) {
      treeSummary = '${treeSummary.substring(0, maxTreeChars)}\n… (tree truncated)';
      treeTruncated = true;
    }

    final agentsMd = await _readFirstExisting([
      p.join(absolute, 'AGENTS.md'),
      p.join(absolute, 'agents.md'),
    ]);
    final readmeMd = await _readFirstExisting([
      p.join(absolute, 'README.md'),
      p.join(absolute, 'readme.md'),
    ]);
    final cursorRules = await _readFirstExisting([
      p.join(absolute, '.cursorrules'),
      p.join(absolute, '.cursor', 'rules'),
    ]);

    final keyFiles = <String>[];
    for (final name in _keyFileNames) {
      if (await File(p.join(absolute, name)).exists()) {
        keyFiles.add(name);
      }
    }

    return WorkspaceMemory(
      workspacePath: absolute,
      fingerprint: fingerprint,
      scannedAt: DateTime.now(),
      fileCount: fileCount,
      directoryCount: dirCount,
      fileTreeSummary: treeSummary,
      agentsMd: agentsMd,
      readmeMd: readmeMd,
      cursorRules: cursorRules,
      keyFiles: keyFiles,
      truncated: treeTruncated || fileCount >= maxFiles,
    );
  }

  Future<void> _walkTree({
    required Directory directory,
    required int depth,
    required String prefix,
    required StringBuffer treeBuffer,
    required int Function() fileCount,
    required void Function(int) setFileCount,
    required int Function() dirCount,
    required void Function(int) setDirCount,
    required void Function() onTruncated,
  }) async {
    if (depth >= maxDepth) return;

    final entries = <FileSystemEntity>[];
    try {
      await for (final entity in directory.list(followLinks: false)) {
        entries.add(entity);
      }
    } catch (_) {
      return;
    }

    entries.sort(
      (a, b) => p.basename(a.path).toLowerCase().compareTo(
        p.basename(b.path).toLowerCase(),
      ),
    );

    for (var i = 0; i < entries.length; i++) {
      if (fileCount() >= maxFiles) {
        onTruncated();
        treeBuffer.writeln('$prefix… (${maxFiles}+ entries, scan capped)');
        return;
      }

      final entity = entries[i];
      final name = p.basename(entity.path);
      if (name.startsWith('.') && !_keyFileNames.contains(name)) {
        continue;
      }

      final isLast = i == entries.length - 1;
      final branch = isLast ? '└── ' : '├── ';
      final childPrefix = isLast ? '$prefix    ' : '$prefix│   ';

      if (entity is Directory) {
        if (_skipDirNames.contains(name)) {
          treeBuffer.writeln('$prefix$branch$name/ (skipped)');
          continue;
        }
        setDirCount(dirCount() + 1);
        treeBuffer.writeln('$prefix$branch$name/');
        await _walkTree(
          directory: entity,
          depth: depth + 1,
          prefix: childPrefix,
          treeBuffer: treeBuffer,
          fileCount: fileCount,
          setFileCount: setFileCount,
          dirCount: dirCount,
          setDirCount: setDirCount,
          onTruncated: onTruncated,
        );
      } else if (entity is File) {
        setFileCount(fileCount() + 1);
        treeBuffer.writeln('$prefix$branch$name');
      }
    }
  }

  Future<String?> loadLastWorkspacePath() => _repository.loadLastWorkspacePath();
  Future<void> saveLastWorkspacePath(String path) => _repository.saveLastWorkspacePath(path);

  Future<String?> _readFirstExisting(List<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) continue;
      try {
        final content = await file.readAsString();
        if (content.length <= maxReadBytes) return content;
        return '${content.substring(0, maxReadBytes)}\n… (truncated)';
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  String buildPromptSection(WorkspaceMemory memory, {WorkspaceInfo? info}) {
    final buffer = StringBuffer();
    buffer.writeln('Workspace memory (cached by Grokker):');
    buffer.writeln(
      'Last scanned: ${memory.scannedAt.toIso8601String()} · '
      '${memory.fileCount} files · ${memory.directoryCount} folders',
    );
    if (info != null) {
      buffer.writeln('Project type: ${info.primaryProjectType}');
      if (info.gitBranch != null) {
        buffer.writeln('Git branch: ${info.gitBranch}');
      }
    }
    if (memory.keyFiles.isNotEmpty) {
      buffer.writeln('Key files: ${memory.keyFiles.join(', ')}');
    }
    if (memory.truncated) {
      buffer.writeln(
        'Note: Large workspace — tree scan was capped for performance.',
      );
    }

    if (memory.fileTreeSummary.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Directory structure:');
      buffer.writeln(memory.fileTreeSummary);
    }

    if (memory.agentsMd != null && memory.agentsMd!.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('AGENTS.md:');
      buffer.writeln(memory.agentsMd!.trim());
    }

    if (memory.cursorRules != null && memory.cursorRules!.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('.cursorrules:');
      buffer.writeln(memory.cursorRules!.trim());
    }

    if (memory.readmeMd != null && memory.readmeMd!.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('README.md:');
      buffer.writeln(memory.readmeMd!.trim());
    }

    var section = buffer.toString().trim();
    if (section.length > maxPromptChars) {
      section =
          '${section.substring(0, maxPromptChars)}\n… (workspace memory truncated for prompt size)';
    }
    return section;
  }
}