import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/widgets/rich_text_editor.dart';

void main() {
  Widget buildEditor({String initialText = ''}) {
    return MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(
        body: SizedBox(
          height: 420,
          child: RichTextEditor(
            initialText: initialText,
            onTextChanged: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('inserts a validated Markdown link', (tester) async {
    await tester.pumpWidget(buildEditor(initialText: 'Read this'));
    final editor = tester.widget<TextField>(find.byType(TextField));
    editor.controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 9,
    );

    await tester.tap(find.byTooltip('Insert Link'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'https://example.com',
    );
    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();

    expect(editor.controller!.text, '[Read this](https://example.com)');
  });

  testWidgets('inserts a Markdown image with alt text', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.tap(find.byTooltip('Insert Image'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'https://example.com/image.png');
    await tester.enterText(fields.at(1), 'Focus desk');
    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();

    final editor = tester.widget<TextField>(find.byType(TextField));
    expect(
      editor.controller!.text,
      '![Focus desk](https://example.com/image.png)',
    );
  });
}
