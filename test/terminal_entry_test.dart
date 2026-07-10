import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/terminal/presentation/widgets/terminal_entry_tile.dart';
import 'package:grokker/features/terminal/presentation/widgets/terminal_palette.dart';
import 'package:grokker/shared/models/chat_message.dart';

void main() {
  group('TerminalPalette.tool labels', () {
    test('uses bare tool id without colon payload', () {
      final message = ChatMessage(
        id: '1',
        role: ChatMessageRole.tool,
        content: 'run_terminal_command: pending',
        createdAt: DateTime(2026),
        title: 'run_terminal_command',
      );
      expect(TerminalPalette.label(message), 'run_terminal_command');
    });

    test('falls back to tool when title missing', () {
      final message = ChatMessage(
        id: '2',
        role: ChatMessageRole.tool,
        content: ': completed',
        createdAt: DateTime(2026),
      );
      expect(TerminalPalette.label(message), 'tool');
    });
  });

  testWidgets('tool tile stacks label above body without overflow', (
    tester,
  ) async {
    final message = ChatMessage(
      id: '3',
      role: ChatMessageRole.tool,
      title: 'run_terminal_command',
      content: 'run_terminal_command: pending',
      createdAt: DateTime(2026),
      status: ChatMessageStatus.pending,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            child: TerminalEntryTile(message: message),
          ),
        ),
      ),
    );

    expect(find.textContaining('run_terminal_command'), findsWidgets);
    // Status body remains after stripping redundant title prefix.
    expect(find.textContaining('pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
