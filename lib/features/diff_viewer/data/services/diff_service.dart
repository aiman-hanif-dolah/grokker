import 'package:uuid/uuid.dart';

import '../../../../shared/models/diff_file.dart';

class DiffService {
  DiffService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  final _snapshots = <String, String>{};

  void snapshotBefore(String path, String content) {
    _snapshots[path] = content;
  }

  DiffFile computeDiff({
    required String path,
    required String afterContent,
    DiffStatus status = DiffStatus.applied,
  }) {
    final before = _snapshots[path] ?? '';
    final unified = _simpleUnified(before, afterContent);

    return DiffFile(
      id: _uuid.v4(),
      path: path,
      unifiedDiff: unified,
      status: status,
      beforeContent: before,
      afterContent: afterContent,
    );
  }

  String _simpleUnified(String before, String after) {
    if (before == after) return '(no changes)';

    final beforeLines = before.split('\n');
    final afterLines = after.split('\n');
    final buffer = StringBuffer('--- before\n+++ after\n');

    final maxLen = beforeLines.length > afterLines.length
        ? beforeLines.length
        : afterLines.length;

    for (var i = 0; i < maxLen; i++) {
      final b = i < beforeLines.length ? beforeLines[i] : null;
      final a = i < afterLines.length ? afterLines[i] : null;
      if (b != a) {
        if (b != null) buffer.writeln('-$b');
        if (a != null) buffer.writeln('+$a');
      }
    }

    return buffer.toString().trimRight();
  }

  void clearSnapshot(String path) => _snapshots.remove(path);
}
