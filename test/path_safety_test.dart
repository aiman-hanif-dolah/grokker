import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/core/utils/path_safety.dart';

void main() {
  group('PathSafety', () {
    test('detects traversal', () {
      expect(PathSafety.isTraversalAttempt('../etc/passwd'), true);
      expect(PathSafety.isTraversalAttempt('safe/file.txt'), false);
    });

    test('workspace boundary check', () {
      expect(
        PathSafety.isInsideWorkspace(
          filePath: '/workspace/lib/main.dart',
          workspacePath: '/workspace',
        ),
        true,
      );
      expect(
        PathSafety.isInsideWorkspace(
          filePath: '/other/file.dart',
          workspacePath: '/workspace',
        ),
        false,
      );
    });
  });
}
