import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../shared/models/grok_model.dart';
import '../../../../shared/models/thinking_effort.dart';
import '../../domain/models/app_session.dart';

class SessionRepository {
  static const _fileName = 'sessions.json';

  Future<File> _storageFile() async {
    final dir = await getApplicationSupportDirectory();
    final grokkerDir = Directory(p.join(dir.path, 'grokker'));
    if (!await grokkerDir.exists()) {
      await grokkerDir.create(recursive: true);
    }
    return File(p.join(grokkerDir.path, _fileName));
  }

  Future<List<AppSession>> loadAll() async {
    final file = await _storageFile();
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => AppSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(
    List<AppSession> sessions, {
    int maxSessions = 100,
  }) async {
    final sorted = [...sessions]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final trimmed = sorted.take(maxSessions).toList();
    final file = await _storageFile();
    await file.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(trimmed.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> delete(String sessionId, List<AppSession> current) async {
    final updated = current.where((s) => s.id != sessionId).toList();
    await saveAll(updated);
  }

  String exportMarkdown(AppSession session) {
    final buffer = StringBuffer();
    buffer.writeln('# ${session.title}');
    buffer.writeln();
    buffer.writeln('- Workspace: ${session.workspacePath}');
    buffer.writeln('- Model: ${session.selectedModel.displayName}');
    buffer.writeln('- Effort: ${session.selectedEffort.displayName}');
    buffer.writeln('- Created: ${session.createdAt.toIso8601String()}');
    buffer.writeln();
    for (final message in session.messages) {
      buffer.writeln('## ${message.role.name}');
      buffer.writeln(message.content);
      buffer.writeln();
    }
    return buffer.toString();
  }
}
