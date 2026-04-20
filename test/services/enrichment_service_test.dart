import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:audiovault/models/audiobook.dart';
import 'package:audiovault/services/enrichment_service.dart';

/// A fake [http.Client] whose [get] never completes until [close] is called,
/// at which point it throws [ClientException] — matching real client behaviour.
class _HangingClient extends http.BaseClient {
  final _completer = Completer<http.StreamedResponse>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _completer.future;

  @override
  void close() {
    if (!_completer.isCompleted) {
      _completer.completeError(
        http.ClientException('Client closed', request?.url),
      );
    }
    super.close();
  }

  http.BaseRequest? request;
}

void main() {
  group('isValidCoverResponse', () {
    test('accepts a plausible JPEG response', () {
      expect(
        isValidCoverResponse(
          statusCode: 200,
          contentType: 'image/jpeg',
          contentLength: 50 * 1024,
        ),
        isTrue,
      );
    });

    test('accepts PNG and WebP', () {
      for (final type in ['image/png', 'image/webp', 'image/gif']) {
        expect(
          isValidCoverResponse(
            statusCode: 200,
            contentType: type,
            contentLength: 1024,
          ),
          isTrue,
          reason: 'expected $type to be accepted',
        );
      }
    });

    test('rejects non-200 status codes', () {
      for (final code in [204, 301, 404, 500]) {
        expect(
          isValidCoverResponse(
            statusCode: code,
            contentType: 'image/jpeg',
            contentLength: 1024,
          ),
          isFalse,
          reason: 'expected status $code to be rejected',
        );
      }
    });

    test('rejects missing content type', () {
      expect(
        isValidCoverResponse(
          statusCode: 200,
          contentType: null,
          contentLength: 1024,
        ),
        isFalse,
      );
    });

    test('rejects non-image content types (e.g. HTML error page)', () {
      expect(
        isValidCoverResponse(
          statusCode: 200,
          contentType: 'text/html; charset=utf-8',
          contentLength: 1024,
        ),
        isFalse,
      );
    });

    test('is case-insensitive on content type', () {
      expect(
        isValidCoverResponse(
          statusCode: 200,
          contentType: 'IMAGE/JPEG',
          contentLength: 1024,
        ),
        isTrue,
      );
    });

    test('rejects suspiciously tiny responses', () {
      expect(
        isValidCoverResponse(
          statusCode: 200,
          contentType: 'image/jpeg',
          contentLength: minCoverBytes - 1,
        ),
        isFalse,
      );
    });

    test('rejects oversized responses', () {
      expect(
        isValidCoverResponse(
          statusCode: 200,
          contentType: 'image/jpeg',
          contentLength: maxCoverBytes + 1,
        ),
        isFalse,
      );
    });

    test('accepts exactly at size boundaries', () {
      expect(
        isValidCoverResponse(
          statusCode: 200,
          contentType: 'image/jpeg',
          contentLength: minCoverBytes,
        ),
        isTrue,
      );
      expect(
        isValidCoverResponse(
          statusCode: 200,
          contentType: 'image/jpeg',
          contentLength: maxCoverBytes,
        ),
        isTrue,
      );
    });
  });

  group('EnrichmentService.cancel', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('cancel() aborts an in-flight request and loop completes promptly',
        () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (db, _) => db.execute('''
            CREATE TABLE enrichment (
              book_path TEXT PRIMARY KEY,
              enriched INTEGER NOT NULL DEFAULT 0,
              cover_path TEXT,
              last_enriched_date INTEGER,
              last_attempted_date INTEGER
            )
          '''),
        ),
      );
      final client = _HangingClient();
      final svc = EnrichmentService.withDatabase(db, client: client);

      final book = Audiobook(
        title: 'Hanging Book',
        path: '/tmp/hanging',
        audioFiles: const [],
      );

      // Start the queue — it will hang on the first HTTP request.
      final loopFuture = svc.enqueueBooks([book]);

      // Give the loop a moment to reach the HTTP call.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final stopwatch = Stopwatch()..start();
      svc.cancel();

      // Loop should complete well within 1 second once the client is closed.
      await loopFuture.timeout(const Duration(seconds: 1));
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
