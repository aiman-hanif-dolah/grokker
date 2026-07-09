import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/acp/data/services/grok_cli_locator_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GrokCliLocatorService', () {
    final service = GrokCliLocatorService();
    final home = GrokCliLocatorService.resolveHomeDirectory();

    test('resolveHomeDirectory returns a path', () {
      expect(home, isNotNull);
      expect(home, isNotEmpty);
    });

    test('resolveHomeDirectory ignores macOS sandbox container HOME', () {
      final user = Platform.environment['USER'];
      if (user == null) return;

      final resolved = GrokCliLocatorService.resolveHomeDirectory();
      expect(resolved, isNot(contains('/Library/Containers/')));
      expect(resolved, '/Users/$user');
    });

    test('officialGrokPath points to ~/.grok/bin/grok', () {
      final path = GrokCliLocatorService.officialGrokPath();
      if (home != null) {
        expect(path, '$home/.grok/bin/grok');
      }
    });

    test('rejects Homebrew log grok if present', () async {
      const homebrewGrok = '/opt/homebrew/bin/grok';
      if (!File(homebrewGrok).existsSync()) return;

      final result = await GrokCliLocatorService.validateGrokBuildCli(
        homebrewGrok,
      );
      expect(result.isValid, isFalse);
    });

    test('accepts official xAI grok when present', () async {
      final official = GrokCliLocatorService.officialGrokPath();
      if (official == null || !File(official).existsSync()) return;

      final result = await GrokCliLocatorService.validateGrokBuildCli(official);
      expect(result.isValid, isTrue);
      expect(result.version, contains('grok'));
    });

    test('detect prefers official grok over Homebrew', () async {
      final official = GrokCliLocatorService.officialGrokPath();
      if (official == null || !File(official).existsSync()) return;

      final result = await service.detect();
      expect(result.found, isTrue);
      expect(result.resolvedPath, isNotNull);
      expect(result.resolvedPath, contains('.grok'));
      expect(result.version, contains('0.2'));
    });

    test('augmentedEnvironment includes ~/.grok/bin in PATH', () {
      final env = GrokCliLocatorService.augmentedEnvironment();
      if (home != null) {
        expect(env['PATH'], contains('$home/.grok/bin'));
        expect(env['HOME'], home);
      }
    });
  });
}
