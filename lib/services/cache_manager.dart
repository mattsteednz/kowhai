import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages cached metadata and cover images for remote Google Drive books.
/// 
/// Cache structure:
/// ```
/// <app_cache_dir>/drive_books/
///   <folder_id_1>/
///     metadata.json
///     cover.jpg
///   <folder_id_2>/
///     metadata.json
///     cover.jpg
/// ```
class CacheManager {
  static void _log(String msg) => debugPrint('[AudioVault:CacheManager] $msg');

  /// Returns the cache directory for a specific folder ID.
  Future<Directory> _cacheDir(String folderId) async {
    final cacheRoot = await getApplicationCacheDirectory();
    return Directory('${cacheRoot.path}/drive_books/$folderId');
  }

  /// Stores metadata JSON for a remote book.
  /// 
  /// Expected metadata format:
  /// ```json
  /// {
  ///   "folderName": "Book Title",
  ///   "accountEmail": "user@example.com",
  ///   "addedAt": 1234567890,
  ///   "audioFileCount": 12,
  ///   "totalSizeBytes": 524288000
  /// }
  /// ```
  Future<void> storeMetadata(String folderId, Map<String, dynamic> metadata) async {
    try {
      final dir = await _cacheDir(folderId);
      await dir.create(recursive: true);
      
      final metadataFile = File('${dir.path}/metadata.json');
      final jsonString = jsonEncode(metadata);
      await metadataFile.writeAsString(jsonString);
      
      _log('Stored metadata for folder $folderId');
    } catch (e) {
      _log('Failed to store metadata for folder $folderId: $e');
      rethrow;
    }
  }

  /// Retrieves metadata for a remote book.
  /// 
  /// Returns null if metadata file doesn't exist or is corrupted.
  Future<Map<String, dynamic>?> getMetadata(String folderId) async {
    try {
      final dir = await _cacheDir(folderId);
      final metadataFile = File('${dir.path}/metadata.json');
      
      if (!await metadataFile.exists()) {
        return null;
      }
      
      final jsonString = await metadataFile.readAsString();
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      _log('Failed to retrieve metadata for folder $folderId: $e');
      return null;
    }
  }

  /// Stores cover image for a remote book.
  Future<void> storeCover(String folderId, List<int> imageBytes) async {
    try {
      final dir = await _cacheDir(folderId);
      await dir.create(recursive: true);
      
      final coverFile = File('${dir.path}/cover.jpg');
      await coverFile.writeAsBytes(imageBytes);
      
      _log('Stored cover for folder $folderId (${imageBytes.length} bytes)');
    } catch (e) {
      _log('Failed to store cover for folder $folderId: $e');
      rethrow;
    }
  }

  /// Retrieves cover path for a remote book.
  /// 
  /// Returns null if cover file doesn't exist.
  Future<String?> getCoverPath(String folderId) async {
    try {
      final dir = await _cacheDir(folderId);
      final coverFile = File('${dir.path}/cover.jpg');
      
      if (await coverFile.exists()) {
        return coverFile.path;
      }
      return null;
    } catch (e) {
      _log('Failed to get cover path for folder $folderId: $e');
      return null;
    }
  }

  /// Migrates metadata and cover from cache to audiobook folder.
  /// 
  /// Copies metadata.json and cover.jpg from cache to the destination directory.
  /// Handles missing cache files gracefully by logging and continuing.
  Future<void> migrateToFolder(String folderId, String destDir) async {
    try {
      final cacheDirectory = await _cacheDir(folderId);
      final destDirectory = Directory(destDir);
      
      // Ensure destination directory exists
      await destDirectory.create(recursive: true);
      
      // Migrate metadata if it exists
      final cachedMetadata = File('${cacheDirectory.path}/metadata.json');
      if (await cachedMetadata.exists()) {
        final destMetadata = File('${destDirectory.path}/metadata.json');
        await cachedMetadata.copy(destMetadata.path);
        _log('Migrated metadata for folder $folderId to $destDir');
      } else {
        _log('No cached metadata to migrate for folder $folderId');
      }
      
      // Migrate cover if it exists
      final cachedCover = File('${cacheDirectory.path}/cover.jpg');
      if (await cachedCover.exists()) {
        final destCover = File('${destDirectory.path}/cover.jpg');
        await cachedCover.copy(destCover.path);
        _log('Migrated cover for folder $folderId to $destDir');
      } else {
        _log('No cached cover to migrate for folder $folderId');
      }
    } catch (e) {
      _log('Failed to migrate cache for folder $folderId to $destDir: $e');
      rethrow;
    }
  }

  /// Deletes all cached data for a folder ID.
  /// 
  /// Removes the entire cache directory for the specified folder.
  /// Handles missing directories gracefully.
  Future<void> deleteCachedData(String folderId) async {
    try {
      final dir = await _cacheDir(folderId);
      
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        _log('Deleted cached data for folder $folderId');
      } else {
        _log('No cached data to delete for folder $folderId');
      }
    } catch (e) {
      _log('Failed to delete cached data for folder $folderId: $e');
      rethrow;
    }
  }

  /// Identifies orphaned cache entries not in the provided set.
  /// 
  /// Returns a list of folder IDs that exist in the cache but are not
  /// in the validFolderIds set.
  Future<List<String>> findOrphanedEntries(Set<String> validFolderIds) async {
    try {
      final cacheRoot = await getApplicationCacheDirectory();
      final driveBooksCache = Directory('${cacheRoot.path}/drive_books');
      
      if (!await driveBooksCache.exists()) {
        _log('Cache directory does not exist, no orphans to find');
        return [];
      }
      
      final orphanedIds = <String>[];
      
      await for (final entity in driveBooksCache.list()) {
        if (entity is Directory) {
          // Use path separator to extract folder ID (works on both Unix and Windows)
          final folderId = entity.path.split(Platform.pathSeparator).last;
          if (!validFolderIds.contains(folderId)) {
            orphanedIds.add(folderId);
          }
        }
      }
      
      _log('Found ${orphanedIds.length} orphaned cache entries');
      return orphanedIds;
    } catch (e) {
      _log('Failed to find orphaned entries: $e');
      return [];
    }
  }

  /// Deletes orphaned cache entries.
  /// 
  /// Returns the count of successfully deleted entries.
  Future<int> cleanupOrphans(List<String> orphanedFolderIds) async {
    int deletedCount = 0;
    
    for (final folderId in orphanedFolderIds) {
      try {
        await deleteCachedData(folderId);
        deletedCount++;
      } catch (e) {
        _log('Failed to delete orphaned cache for folder $folderId: $e');
        // Continue with remaining orphans
      }
    }
    
    _log('Cleaned up $deletedCount orphaned cache entries');
    return deletedCount;
  }
}
