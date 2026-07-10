import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/chat/data/services/session_title_service.dart';

void main() {
  final service = SessionTitleService();

  group('SessionTitleService', () {
    test('detects placeholder titles', () {
      expect(service.isPlaceholderTitle('Session 4'), isTrue);
      expect(service.isPlaceholderTitle('New chat'), isTrue);
      expect(service.isPlaceholderTitle('Fix auth bug'), isFalse);
    });

    test('parses clean title from Grok response', () {
      expect(
        service.parseTitle('Flutter Login Screen'),
        'Flutter Login Screen',
      );
      expect(
        service.parseTitle('"Dark Theme Redesign"'),
        'Dark Theme Redesign',
      );
      expect(
        service.parseTitle('Title: API Rate Limiting'),
        'API Rate Limiting',
      );
    });

    test('buildTitlePrompt includes user message', () {
      final prompt = service.buildTitlePrompt(userMessage: 'build a todo app');
      expect(prompt, contains('todo app'));
      expect(prompt, contains('session title'));
    });
  });
}
