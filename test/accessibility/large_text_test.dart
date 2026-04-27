import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kowhai/models/audiobook.dart';
import 'package:kowhai/services/enrichment_service.dart';
import 'package:kowhai/widgets/audiobook_card.dart';
import 'package:kowhai/widgets/audiobook_list_tile.dart';

Audiobook _book({String title = 'A Very Long Audiobook Title That Might Wrap'}) =>
    Audiobook(
      title: title,
      author: 'Author Name',
      path: '/tmp/book',
      audioFiles: const [],
      duration: const Duration(hours: 12, minutes: 34),
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.0),
          ),
          child: SizedBox(width: 400, height: 600, child: child),
        ),
      ),
    );

void main() {
  setUpAll(() {
    // Register a minimal EnrichmentService so _EnrichmentAwareCover can resolve it.
    if (!GetIt.I.isRegistered<EnrichmentService>()) {
      GetIt.I.registerLazySingleton<EnrichmentService>(() => EnrichmentService());
    }
  });

  group('Large text (2×) — no overflow', () {
    testWidgets('AudiobookCard renders without overflow at 2× text scale',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AudiobookCard(
          book: _book(),
          status: BookStatus.inProgress,
          placeholderIndex: 0,
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AudiobookListTile renders without overflow at 2× text scale',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AudiobookListTile(
          book: _book(),
          status: BookStatus.inProgress,
          placeholderIndex: 0,
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AudiobookCard with active badge renders without overflow',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AudiobookCard(
          book: _book(),
          isActive: true,
          status: BookStatus.inProgress,
          placeholderIndex: 0,
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AudiobookCard with finished badge renders without overflow',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AudiobookCard(
          book: _book(),
          status: BookStatus.finished,
          placeholderIndex: 0,
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
