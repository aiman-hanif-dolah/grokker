import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/shared/models/app_settings.dart';

void main() {
  group('Composer enter behavior', () {
    test('send mode uses send as default in fresh settings', () {
      expect(
        const AppSettings().composerEnterBehavior,
        ComposerEnterBehavior.send,
      );
    });

    test('newline mode is preserved in copyWith', () {
      final settings = const AppSettings().copyWith(
        composerEnterBehavior: ComposerEnterBehavior.newline,
      );
      expect(settings.composerEnterBehavior, ComposerEnterBehavior.newline);
    });
  });
}
