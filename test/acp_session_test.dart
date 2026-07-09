import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/acp/data/services/grok_cli_locator_service.dart';

void main() {
  test('official home can be used as session cwd fallback', () {
    final home = GrokCliLocatorService.resolveHomeDirectory();
    expect(home, isNotNull);
    expect(home, isNot(contains('/Library/Containers/')));
  });
}
