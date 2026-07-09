import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/diff_viewer/data/services/diff_service.dart';
import 'package:grokker/shared/models/diff_file.dart';

void main() {
  test('computes unified diff', () {
    final service = DiffService();
    service.snapshotBefore('/a.dart', 'line1\nline2');
    final diff = service.computeDiff(
      path: '/a.dart',
      afterContent: 'line1\nline2 changed',
      status: DiffStatus.applied,
    );
    expect(diff.unifiedDiff, contains('-line2'));
    expect(diff.unifiedDiff, contains('+line2 changed'));
  });
}
