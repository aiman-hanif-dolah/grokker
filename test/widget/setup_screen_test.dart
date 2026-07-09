import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/setup/presentation/setup_screen.dart';

void main() {
  testWidgets('setup screen shows Grok CLI not found message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(error: 'Command not found', onRetry: () {}),
      ),
    );

    expect(find.text('Grok CLI not found.'), findsOneWidget);
    expect(find.text('Retry detection'), findsOneWidget);
    expect(find.textContaining('grok /login'), findsWidgets);
  });
}
