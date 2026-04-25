import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:audiovault/services/cache_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Mock implementation of PathProviderPlatform for testing
class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String tempPath;

  MockPathProviderPlatform(this.tempPath);

  @override
  Future<String?> getApplicationCachePath() async => tempPath;
}

void main() {
  late Directory tempDir;
  late CacheManager cacheManager;

  setUp(() async {
    // Create a temporary directory for testing
    tempDir = await Directory.systemTemp.createTemp('cache_manager_test_');
    
    // Set up mock path provider
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);
    
    cacheManager = CacheManager();
  });

  tearDown(() async {
    // Clean up temporary directory
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Metadata Storage and Retrieval', () {
    test('storeMetadata creates cache directory and stores JSON', () async {
      const folderId = 'test-folder-1';
      final metadata = {
        'folderName': 'Test Book',
        'accountEmail': 'user@example.com',
        'addedAt': 1234567890,
        'audioFileCount': 12,
        'totalSizeBytes': 524288000,
      };

      await cacheManager.storeMetadata(folderId, metadata);

      final cacheDir = Directory('${tempDir.path}/drive_books/$folderId');
      expect(await cacheDir.exists(), isTrue);

      final metadataFile = File('${cacheDir.path}/metadata.json');
      expect(await metadataFile.exists(), isTrue);

      final storedContent = await metadataFile.readAsString();
      final storedMetadata = jsonDecode(storedContent);
      expect(storedMetadata, equals(metadata));
    });

    test('getMetadata retrieves stored metadata', () async {
      const folderId = 'test-folder-2';
      final metadata = {
        'folderName': 'Another Book',
        'accountEmail': 'test@example.com',
        'addedAt': 9876543210,
      };

      await cacheManager.storeMetadata(folderId, metadata);
      final retrieved = await cacheManager.getMetadata(folderId);

      expect(retrieved, isNotNull);
      expect(retrieved, equals(metadata));
    });

    test('getMetadata returns null for non-existent folder', () async {
      final retrieved = await cacheManager.getMetadata('non-existent-folder');
      expect(retrieved, isNull);
    });

    test('storeMetadata overwrites existing metadata', () async {
      const folderId = 'test-folder-3';
      final metadata1 = {'folderName': 'First Name'};
      final metadata2 = {'folderName': 'Second Name'};

      await cacheManager.storeMetadata(folderId, metadata1);
      await cacheManager.storeMetadata(folderId, metadata2);

      final retrieved = await cacheManager.getMetadata(folderId);
      expect(retrieved?['folderName'], equals('Second Name'));
    });
  });

  group('Cover Image Storage and Retrieval', () {
    test('storeCover creates cache directory and stores image bytes', () async {
      const folderId = 'test-folder-4';
      final imageBytes = List<int>.generate(1024, (i) => i % 256);

      await cacheManager.storeCover(folderId, imageBytes);

      final cacheDir = Directory('${tempDir.path}/drive_books/$folderId');
      expect(await cacheDir.exists(), isTrue);

      final coverFile = File('${cacheDir.path}/cover.jpg');
      expect(await coverFile.exists(), isTrue);

      final storedBytes = await coverFile.readAsBytes();
      expect(storedBytes, equals(imageBytes));
    });

    test('getCoverPath returns path for existing cover', () async {
      const folderId = 'test-folder-5';
      final imageBytes = [1, 2, 3, 4, 5];

      await cacheManager.storeCover(folderId, imageBytes);
      final coverPath = await cacheManager.getCoverPath(folderId);

      expect(coverPath, isNotNull);
      expect(coverPath, endsWith('/drive_books/$folderId/cover.jpg'));
      expect(await File(coverPath!).exists(), isTrue);
    });

    test('getCoverPath returns null for non-existent cover', () async {
      final coverPath = await cacheManager.getCoverPath('non-existent-folder');
      expect(coverPath, isNull);
    });

    test('storeCover overwrites existing cover', () async {
      const folderId = 'test-folder-6';
      final imageBytes1 = [1, 2, 3];
      final imageBytes2 = [4, 5, 6, 7, 8];

      await cacheManager.storeCover(folderId, imageBytes1);
      await cacheManager.storeCover(folderId, imageBytes2);

      final coverPath = await cacheManager.getCoverPath(folderId);
      final storedBytes = await File(coverPath!).readAsBytes();
      expect(storedBytes, equals(imageBytes2));
    });
  });

  group('Missing Cache Directory Handling', () {
    test('getMetadata handles missing cache directory gracefully', () async {
      final retrieved = await cacheManager.getMetadata('never-created');
      expect(retrieved, isNull);
    });

    test('getCoverPath handles missing cache directory gracefully', () async {
      final coverPath = await cacheManager.getCoverPath('never-created');
      expect(coverPath, isNull);
    });

    test('storeMetadata creates missing parent directories', () async {
      const folderId = 'deeply/nested/folder/id';
      final metadata = {'test': 'data'};

      await cacheManager.storeMetadata(folderId, metadata);
      final retrieved = await cacheManager.getMetadata(folderId);

      expect(retrieved, equals(metadata));
    });
  });

  group('Corrupted Metadata Files', () {
    test('getMetadata returns null for corrupted JSON', () async {
      const folderId = 'corrupted-folder';
      final cacheDir = Directory('${tempDir.path}/drive_books/$folderId');
      await cacheDir.create(recursive: true);

      final metadataFile = File('${cacheDir.path}/metadata.json');
      await metadataFile.writeAsString('{ invalid json content }');

      final retrieved = await cacheManager.getMetadata(folderId);
      expect(retrieved, isNull);
    });

    test('getMetadata returns null for empty metadata file', () async {
      const folderId = 'empty-folder';
      final cacheDir = Directory('${tempDir.path}/drive_books/$folderId');
      await cacheDir.create(recursive: true);

      final metadataFile = File('${cacheDir.path}/metadata.json');
      await metadataFile.writeAsString('');

      final retrieved = await cacheManager.getMetadata(folderId);
      expect(retrieved, isNull);
    });

    test('getMetadata returns null for non-JSON content', () async {
      const folderId = 'text-folder';
      final cacheDir = Directory('${tempDir.path}/drive_books/$folderId');
      await cacheDir.create(recursive: true);

      final metadataFile = File('${cacheDir.path}/metadata.json');
      await metadataFile.writeAsString('This is plain text, not JSON');

      final retrieved = await cacheManager.getMetadata(folderId);
      expect(retrieved, isNull);
    });
  });

  group('Performance Tests', () {
    test('metadata retrieval completes in < 100ms', () async {
      const folderId = 'perf-test-folder';
      final metadata = {
        'folderName': 'Performance Test Book',
        'accountEmail': 'perf@example.com',
        'addedAt': 1234567890,
        'audioFileCount': 50,
        'totalSizeBytes': 1073741824,
      };

      await cacheManager.storeMetadata(folderId, metadata);

      final stopwatch = Stopwatch()..start();
      final retrieved = await cacheManager.getMetadata(folderId);
      stopwatch.stop();

      expect(retrieved, isNotNull);
      expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Metadata retrieval took ${stopwatch.elapsedMilliseconds}ms, expected < 100ms');
    });

    test('metadata retrieval with 100 cached books stays under 100ms', () async {
      // Create 100 cached books
      for (int i = 0; i < 100; i++) {
        await cacheManager.storeMetadata('folder-$i', {
          'folderName': 'Book $i',
          'addedAt': 1234567890 + i,
        });
      }

      // Test retrieval time for a specific book
      final stopwatch = Stopwatch()..start();
      final retrieved = await cacheManager.getMetadata('folder-50');
      stopwatch.stop();

      expect(retrieved, isNotNull);
      expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Metadata retrieval took ${stopwatch.elapsedMilliseconds}ms with 100 cached books');
    });
  });

  group('Concurrent Access Scenarios', () {
    test('concurrent metadata reads do not interfere', () async {
      const folderId = 'concurrent-read-folder';
      final metadata = {'folderName': 'Concurrent Test'};

      await cacheManager.storeMetadata(folderId, metadata);

      // Perform 10 concurrent reads
      final futures = List.generate(
        10,
        (_) => cacheManager.getMetadata(folderId),
      );

      final results = await Future.wait(futures);

      // All reads should succeed
      expect(results.every((r) => r != null), isTrue);
      expect(results.every((r) => r?['folderName'] == 'Concurrent Test'), isTrue);
    });

    test('concurrent writes to different folders do not interfere', () async {
      final futures = List.generate(
        10,
        (i) => cacheManager.storeMetadata('folder-$i', {'index': i}),
      );

      await Future.wait(futures);

      // Verify all folders were created correctly
      for (int i = 0; i < 10; i++) {
        final metadata = await cacheManager.getMetadata('folder-$i');
        expect(metadata?['index'], equals(i));
      }
    });

    test('concurrent read and write to same folder completes without error', () async {
      const folderId = 'read-write-folder';
      final metadata1 = {'version': 1};
      final metadata2 = {'version': 2};

      await cacheManager.storeMetadata(folderId, metadata1);

      // Start concurrent read and write
      final readFuture = cacheManager.getMetadata(folderId);
      final writeFuture = cacheManager.storeMetadata(folderId, metadata2);

      await Future.wait([readFuture, writeFuture]);

      // Final state should be version 2
      final finalMetadata = await cacheManager.getMetadata(folderId);
      expect(finalMetadata?['version'], equals(2));
    });

    test('concurrent cover and metadata operations do not interfere', () async {
      const folderId = 'mixed-ops-folder';
      final metadata = {'folderName': 'Mixed Operations'};
      final imageBytes = List<int>.generate(512, (i) => i % 256);

      final metadataFuture = cacheManager.storeMetadata(folderId, metadata);
      final coverFuture = cacheManager.storeCover(folderId, imageBytes);

      await Future.wait([metadataFuture, coverFuture]);

      // Verify both operations succeeded
      final retrievedMetadata = await cacheManager.getMetadata(folderId);
      final coverPath = await cacheManager.getCoverPath(folderId);

      expect(retrievedMetadata, equals(metadata));
      expect(coverPath, isNotNull);
      expect(await File(coverPath!).exists(), isTrue);
    });
  });

  group('Cache Migration', () {
    test('migrateToFolder copies metadata to destination', () async {
      const folderId = 'migrate-folder-1';
      final metadata = {'folderName': 'Migration Test'};
      final destDir = '${tempDir.path}/audiobooks/$folderId';

      await cacheManager.storeMetadata(folderId, metadata);
      await cacheManager.migrateToFolder(folderId, destDir);

      final destMetadata = File('$destDir/metadata.json');
      expect(await destMetadata.exists(), isTrue);

      final content = await destMetadata.readAsString();
      final migratedMetadata = jsonDecode(content);
      expect(migratedMetadata, equals(metadata));
    });

    test('migrateToFolder copies cover to destination', () async {
      const folderId = 'migrate-folder-2';
      final imageBytes = [1, 2, 3, 4, 5];
      final destDir = '${tempDir.path}/audiobooks/$folderId';

      await cacheManager.storeCover(folderId, imageBytes);
      await cacheManager.migrateToFolder(folderId, destDir);

      final destCover = File('$destDir/cover.jpg');
      expect(await destCover.exists(), isTrue);

      final migratedBytes = await destCover.readAsBytes();
      expect(migratedBytes, equals(imageBytes));
    });

    test('migrateToFolder handles missing metadata gracefully', () async {
      const folderId = 'migrate-folder-3';
      final imageBytes = [1, 2, 3];
      final destDir = '${tempDir.path}/audiobooks/$folderId';

      // Only store cover, no metadata
      await cacheManager.storeCover(folderId, imageBytes);
      
      // Should not throw
      await cacheManager.migrateToFolder(folderId, destDir);

      // Cover should be migrated
      final destCover = File('$destDir/cover.jpg');
      expect(await destCover.exists(), isTrue);

      // Metadata should not exist
      final destMetadata = File('$destDir/metadata.json');
      expect(await destMetadata.exists(), isFalse);
    });

    test('migrateToFolder handles missing cover gracefully', () async {
      const folderId = 'migrate-folder-4';
      final metadata = {'folderName': 'No Cover Book'};
      final destDir = '${tempDir.path}/audiobooks/$folderId';

      // Only store metadata, no cover
      await cacheManager.storeMetadata(folderId, metadata);
      
      // Should not throw
      await cacheManager.migrateToFolder(folderId, destDir);

      // Metadata should be migrated
      final destMetadata = File('$destDir/metadata.json');
      expect(await destMetadata.exists(), isTrue);

      // Cover should not exist
      final destCover = File('$destDir/cover.jpg');
      expect(await destCover.exists(), isFalse);
    });

    test('migrateToFolder creates destination directory if missing', () async {
      const folderId = 'migrate-folder-5';
      final metadata = {'folderName': 'Create Dir Test'};
      final destDir = '${tempDir.path}/deep/nested/path/$folderId';

      await cacheManager.storeMetadata(folderId, metadata);
      await cacheManager.migrateToFolder(folderId, destDir);

      expect(await Directory(destDir).exists(), isTrue);
      expect(await File('$destDir/metadata.json').exists(), isTrue);
    });
  });

  group('Cache Deletion', () {
    test('deleteCachedData removes metadata and cover', () async {
      const folderId = 'delete-folder-1';
      final metadata = {'folderName': 'Delete Test'};
      final imageBytes = [1, 2, 3];

      await cacheManager.storeMetadata(folderId, metadata);
      await cacheManager.storeCover(folderId, imageBytes);

      final cacheDir = Directory('${tempDir.path}/drive_books/$folderId');
      expect(await cacheDir.exists(), isTrue);

      await cacheManager.deleteCachedData(folderId);

      expect(await cacheDir.exists(), isFalse);
    });

    test('deleteCachedData handles non-existent cache gracefully', () async {
      // Should not throw
      await cacheManager.deleteCachedData('non-existent-folder');
    });

    test('deleteCachedData does not affect other folders', () async {
      const folderId1 = 'delete-folder-2';
      const folderId2 = 'delete-folder-3';
      final metadata = {'folderName': 'Test'};

      await cacheManager.storeMetadata(folderId1, metadata);
      await cacheManager.storeMetadata(folderId2, metadata);

      await cacheManager.deleteCachedData(folderId1);

      final cacheDir1 = Directory('${tempDir.path}/drive_books/$folderId1');
      final cacheDir2 = Directory('${tempDir.path}/drive_books/$folderId2');

      expect(await cacheDir1.exists(), isFalse);
      expect(await cacheDir2.exists(), isTrue);
    });
  });

  group('Orphaned Cache Detection and Cleanup', () {
    test('findOrphanedEntries identifies orphaned folders', () async {
      // Create cache for 3 folders
      await cacheManager.storeMetadata('folder-1', {'name': 'Book 1'});
      await cacheManager.storeMetadata('folder-2', {'name': 'Book 2'});
      await cacheManager.storeMetadata('folder-3', {'name': 'Book 3'});

      // Only folders 1 and 3 are valid
      final validIds = {'folder-1', 'folder-3'};
      final orphaned = await cacheManager.findOrphanedEntries(validIds);

      expect(orphaned, contains('folder-2'));
      expect(orphaned, isNot(contains('folder-1')));
      expect(orphaned, isNot(contains('folder-3')));
    });

    test('findOrphanedEntries returns empty list when no orphans', () async {
      await cacheManager.storeMetadata('folder-1', {'name': 'Book 1'});
      await cacheManager.storeMetadata('folder-2', {'name': 'Book 2'});

      final validIds = {'folder-1', 'folder-2'};
      final orphaned = await cacheManager.findOrphanedEntries(validIds);

      expect(orphaned, isEmpty);
    });

    test('findOrphanedEntries handles missing cache directory', () async {
      final validIds = {'folder-1'};
      final orphaned = await cacheManager.findOrphanedEntries(validIds);

      expect(orphaned, isEmpty);
    });

    test('cleanupOrphans deletes orphaned entries', () async {
      await cacheManager.storeMetadata('orphan-1', {'name': 'Orphan 1'});
      await cacheManager.storeMetadata('orphan-2', {'name': 'Orphan 2'});

      final orphanedIds = ['orphan-1', 'orphan-2'];
      final deletedCount = await cacheManager.cleanupOrphans(orphanedIds);

      expect(deletedCount, equals(2));

      final cacheDir1 = Directory('${tempDir.path}/drive_books/orphan-1');
      final cacheDir2 = Directory('${tempDir.path}/drive_books/orphan-2');

      expect(await cacheDir1.exists(), isFalse);
      expect(await cacheDir2.exists(), isFalse);
    });

    test('cleanupOrphans handles partial failures gracefully', () async {
      await cacheManager.storeMetadata('orphan-1', {'name': 'Orphan 1'});

      // Include a non-existent folder in the list
      final orphanedIds = ['orphan-1', 'non-existent'];
      final deletedCount = await cacheManager.cleanupOrphans(orphanedIds);

      // Both should be counted as "deleted" (non-existent is handled gracefully)
      expect(deletedCount, equals(2));
    });

    test('cleanupOrphans with 50+ entries completes efficiently', () async {
      // Create 60 orphaned entries
      for (int i = 0; i < 60; i++) {
        await cacheManager.storeMetadata('orphan-$i', {'index': i});
      }

      final orphanedIds = List.generate(60, (i) => 'orphan-$i');

      final stopwatch = Stopwatch()..start();
      final deletedCount = await cacheManager.cleanupOrphans(orphanedIds);
      stopwatch.stop();

      expect(deletedCount, equals(60));
      expect(stopwatch.elapsedMilliseconds, lessThan(5000),
          reason: 'Cleanup of 60 entries took ${stopwatch.elapsedMilliseconds}ms, expected < 5000ms');
    });
  });
}
