import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kowhai/models/audiobook.dart';
import 'package:kowhai/widgets/book_cover.dart';

Audiobook _book() => Audiobook(
      title: 'Test Book',
      path: '/dummy/test-book',
      audioFiles: const [],
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 100, height: 100, child: child),
      ),
    );

void main() {
  testWidgets('placeholder shows coloured tile with title text and no icon by default',
      (tester) async {
    await tester.pumpWidget(_wrap(BookCover(book: _book())));
    expect(find.byType(ColoredBox), findsAtLeastNWidgets(1));
    expect(find.text('Test Book'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows spinner overlay while enriching', (tester) async {
    await tester.pumpWidget(
      _wrap(BookCover(book: _book(), isEnriching: true)),
    );
    expect(find.byType(ColoredBox), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows title text when enrichmentFailed and not enriching',
      (tester) async {
    await tester.pumpWidget(
      _wrap(BookCover(book: _book(), enrichmentFailed: true)),
    );
    // Failed enrichment shows the same coloured tile + title text as the
    // default placeholder — the image_not_supported icon was removed.
    expect(find.byType(ColoredBox), findsAtLeastNWidgets(1));
    expect(find.text('Test Book'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'spinner wins over failed when both flags are somehow set (retry in flight)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(BookCover(
        book: _book(),
        isEnriching: true,
        enrichmentFailed: true,
      )),
    );
    // While enriching, should show the coloured tile + spinner —
    // not the "failed" icon — because the current attempt may still succeed.
    expect(find.byType(ColoredBox), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
