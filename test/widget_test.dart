import 'package:flutter_test/flutter_test.dart';
import 'package:grokker/features/attachments/presentation/widgets/attachment_chips.dart';
import 'package:grokker/shared/models/attachment_item.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('attachment chips render file names', (tester) async {
    const attachments = [
      AttachmentItem(
        id: '1',
        path: '/tmp/test.dart',
        type: AttachmentType.code,
        fileName: 'test.dart',
        sizeBytes: 100,
        mimeType: 'text/plain',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentChips(
            attachments: attachments,
            onRemove: (_) {},
            onTogglePin: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('test.dart'), findsOneWidget);
  });
}
