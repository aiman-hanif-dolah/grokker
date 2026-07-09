import 'dart:io';

import 'package:path/path.dart' as p;

class PathSafety {
  static String normalize(String inputPath) {
    return p.normalize(p.absolute(inputPath));
  }

  static bool isInsideWorkspace({
    required String filePath,
    required String workspacePath,
  }) {
    final normalizedFile = normalize(filePath);
    final normalizedWorkspace = normalize(workspacePath);
    return p.isWithin(normalizedWorkspace, normalizedFile) ||
        normalizedFile == normalizedWorkspace;
  }

  static bool isTraversalAttempt(String inputPath) {
    final segments = p.split(inputPath);
    return segments.contains('..');
  }

  static String toFileUri(String absolutePath) {
    if (Platform.isWindows) {
      final normalized = absolutePath.replaceAll('\\', '/');
      if (normalized.length >= 2 && normalized[1] == ':') {
        return 'file:///${normalized.replaceAll(' ', '%20')}';
      }
    }
    return 'file://${absolutePath.replaceAll(' ', '%20')}';
  }
}
