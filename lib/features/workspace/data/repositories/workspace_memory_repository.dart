import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/workspace_memory.dart';

class WorkspaceMemoryRepository {
  WorkspaceMemoryRepository({
    Future<Directory> Function()? supportDirectoryProvider,
  }) : _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _supportDirectoryProvider;

  Future<Directory> _memoryDir() async {
    final support = await _supportDirectoryProvider();
    final dir = Directory(p.join(support.path, 'grokker', 'workspace_memory'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String cacheKeyForPath(String workspacePath) {
    final normalized = p.normalize(p.absolute(workspacePath));
    return base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
  }

  Future<WorkspaceMemory?> load(String workspacePath) async {
    final file = File(
      p.join(
        (await _memoryDir()).path,
        '${cacheKeyForPath(workspacePath)}.json',
      ),
    );
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return WorkspaceMemory.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(WorkspaceMemory memory) async {
    final file = File(
      p.join(
        (await _memoryDir()).path,
        '${cacheKeyForPath(memory.workspacePath)}.json',
      ),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(memory.toJson()),
    );
  }

  Future<void> delete(String workspacePath) async {
    final file = File(
      p.join(
        (await _memoryDir()).path,
        '${cacheKeyForPath(workspacePath)}.json',
      ),
    );
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File> _lastWorkspaceFile() async {
    final dir = await _memoryDir();
    return File(p.join(dir.path, 'last_workspace.json'));
  }

  Future<String?> loadLastWorkspacePath() async {
    final file = await _lastWorkspaceFile();
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return json['path'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastWorkspacePath(String path) async {
    final file = await _lastWorkspaceFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({'path': path}),
    );
  }
}