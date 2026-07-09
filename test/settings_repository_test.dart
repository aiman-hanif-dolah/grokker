import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/settings/data/repositories/settings_repository.dart';
import 'package:grokker/shared/models/app_settings.dart';
import 'package:grokker/shared/models/approval_mode.dart';
import 'package:grokker/shared/models/grok_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsRepository', () {
    late SettingsRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = SettingsRepository();
    });

    test('loads defaults when empty', () async {
      final settings = await repository.load();
      expect(settings.defaultModel, GrokModel.grokBuild01);
      expect(settings.approvalMode, ApprovalMode.autoApproveReads);
    });

    test('persists and reloads settings', () async {
      const custom = AppSettings(
        grokCommandPath: '/usr/local/bin/grok',
        useNpxGrok: true,
        autoStartGrokProcess: false,
      );
      await repository.save(custom);
      final loaded = await repository.load();
      expect(loaded.grokCommandPath, '/usr/local/bin/grok');
      expect(loaded.useNpxGrok, true);
      expect(loaded.autoStartGrokProcess, false);
    });
  });
}
