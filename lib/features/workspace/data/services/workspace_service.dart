import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../shared/models/workspace_info.dart';

class WorkspaceService {
  Future<WorkspaceInfo> analyze(String folderPath) async {
    final absolute = p.absolute(folderPath);
    final name = p.basename(absolute);
    final dir = Directory(absolute);

    if (!await dir.exists()) {
      return WorkspaceInfo(
        path: absolute,
        name: name,
        projectTypes: const [ProjectType.unknown],
      );
    }

    final types = <ProjectType>[];
    final entries = await dir.list(followLinks: false).take(50).toList();
    final names = entries.map((e) => p.basename(e.path)).toSet();

    if (names.contains('pubspec.yaml')) types.add(ProjectType.flutter);
    if (names.contains('package.json')) types.add(ProjectType.node);
    if (names.contains('pyproject.toml') ||
        names.contains('requirements.txt') ||
        names.contains('setup.py')) {
      types.add(ProjectType.python);
    }
    if (names.contains('Cargo.toml')) types.add(ProjectType.rust);
    if (names.contains('go.mod')) types.add(ProjectType.go);
    if (names.contains('pom.xml') || names.contains('build.gradle')) {
      types.add(ProjectType.java);
    }
    if (names.contains('build.gradle.kts')) types.add(ProjectType.kotlin);
    if (names.contains('Package.swift')) types.add(ProjectType.swift);

    final isGit =
        names.contains('.git') ||
        await Directory(p.join(absolute, '.git')).exists();
    if (isGit) types.add(ProjectType.gitRepo);

    if (types.isEmpty) types.add(ProjectType.general);

    String? branch;
    if (isGit) {
      branch = await _gitBranch(absolute);
    }

    return WorkspaceInfo(
      path: absolute,
      name: name,
      projectTypes: types,
      gitBranch: branch,
      isGitRepo: isGit,
    );
  }

  Future<String?> _gitBranch(String path) async {
    try {
      final result = await Process.run(
        'git',
        ['rev-parse', '--abbrev-ref', 'HEAD'],
        workingDirectory: path,
        runInShell: true,
      );
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {}
    return null;
  }
}
