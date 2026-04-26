# Implementation Tasks

## Phase 1: Database Schema and CacheManager Foundation

### 1.1 Database Schema Migration
- [x] Add `is_downloaded` column to `drive_books` table with default value 0
- [x] Create index on `is_downloaded` column for efficient queries
- [x] Write migration script in `PositionService` to handle schema update
- [x] Test migration with existing database

### 1.2 Create CacheManager Component
- [x] Create `lib/services/cache_manager.dart` file
- [x] Implement `_cacheDir(String folderId)` to return cache directory path
- [x] Implement `storeMetadata(String folderId, Map<String, dynamic> metadata)`
- [x] Implement `getMetadata(String folderId)` with < 100ms performance
- [x] Implement `storeCover(String folderId, List<int> imageBytes)`
- [x] Implement `getCoverPath(String folderId)`
- [x] Add error handling for storage failures
- [x] Add logging for cache operations

### 1.3 CacheManager Unit Tests
- [x] Test storing and retrieving metadata
- [x] Test storing and retrieving cover images
- [x] Test handling missing cache directory
- [x] Test handling corrupted metadata files
- [x] Test performance: metadata retrieval < 100ms
- [x] Test concurrent access scenarios

## Phase 2: Repository Layer Updates

### 2.1 Update DriveBookRepository
- [x] Add `isDownloaded` field to `DriveBookRecord` class
- [x] Update `toMap()` and `fromMap()` methods to include `isDownloaded`
- [x] Implement `markAsDownloaded(String folderId, bool downloaded)`
- [x] Implement `getRemoteOnlyFolderIds()` query
- [x] Implement `findStaleFolderIds(Set<String> scannedFolderIds)`
- [x] Update all existing queries to handle new column

### 2.2 Repository Unit Tests
- [x] Test marking book as downloaded
- [x] Test querying remote-only folder IDs
- [x] Test finding stale folder IDs
- [x] Test database migration
- [x] Test backward compatibility with existing records

## Phase 3: Folder Creation Timing

### 3.1 Modify DriveLibraryService.rescanDrive()
- [x] Remove `await Directory(dir).create(recursive: true)` from scan loop
- [x] Update logic to store metadata in cache instead of creating folders
- [x] Call `_cacheManager.storeMetadata()` for new books
- [x] Call `_cacheManager.storeCover()` for books with cover art
- [x] Set `isDownloaded=false` when creating book records
- [x] Add logging for scan operations

### 3.2 Modify DriveLibraryService.startDownload()
- [x] Add folder creation logic before calling `_downloadManager.enqueueAllFiles()`
- [x] Use `await Directory(dir).create(recursive: true)`
- [x] Add error handling for folder creation failures
- [x] Add logging for folder creation

### 3.3 Integration Tests for Folder Timing
- [x] Test scan does not create folders
- [x] Test download creates folder
- [x] Test folder creation before file download
- [x] Test error handling when folder creation fails

## Phase 4: Cache Migration

### 4.1 Implement CacheManager Migration
- [x] Implement `migrateToFolder(String folderId, String destDir)`
- [x] Copy metadata.json from cache to destination folder
- [x] Copy cover.jpg from cache to destination folder
- [x] Handle missing cache files gracefully
- [x] Add error handling and logging

### 4.2 Implement CacheManager Deletion
- [x] Implement `deleteCachedData(String folderId)`
- [x] Delete metadata.json from cache
- [x] Delete cover.jpg from cache
- [x] Handle missing files gracefully
- [x] Add logging for deletion operations

### 4.3 Modify DriveDownloadManager
- [x] Add `CacheManager` dependency to constructor
- [x] Update `enqueueAllFiles()` to trigger migration after download completes
- [x] Call `_cacheManager.migrateToFolder()` after all files downloaded
- [x] Call `_repo.markAsDownloaded(folderId, true)` after migration
- [x] Call `_cacheManager.deleteCachedData(folderId)` after marking downloaded
- [x] Add error handling for migration failures

### 4.4 Migration Unit Tests
- [x] Test migrating metadata to folder
- [x] Test migrating cover to folder
- [x] Test handling missing cache files
- [x] Test error handling during migration
- [x] Test cache deletion after migration

### 4.5 Integration Tests for Migration
- [x] Test end-to-end: scan → cache → download → migrate
- [x] Test metadata appears in folder after download
- [x] Test cover appears in folder after download
- [x] Test cache deleted after successful migration
- [x] Test book marked as downloaded after migration

## Phase 5: Stale Book Cleanup

### 5.1 Implement Stale Book Detection
- [x] Add `_cleanupStaleBooks(Set<String> scannedFolderIds)` to DriveLibraryService
- [x] Call `_repo.findStaleFolderIds(scannedFolderIds)` to identify stale books
- [x] Filter stale books to only remote-only books (isDownloaded=false)
- [x] Log stale books for user visibility

### 5.2 Implement Stale Book Removal
- [x] Delete stale book records from database
- [x] Call `_cacheManager.deleteCachedData()` for each stale book
- [x] Add error handling for deletion failures
- [x] Add logging for removed books

### 5.3 Integrate Cleanup into Scan
- [x] Call `_cleanupStaleBooks()` at end of `rescanDrive()`
- [x] Pass set of scanned folder IDs to cleanup method
- [x] Handle network errors gracefully (skip cleanup if scan failed)

### 5.4 Stale Book Cleanup Tests
- [x] Test identifying stale remote-only books
- [x] Test removing stale book records
- [x] Test deleting stale book cache
- [x] Test preserving downloaded books
- [x] Test logging of removed books

### 5.5 Integration Tests for Stale Cleanup
- [x] Test stale remote-only book removed after rescan
- [x] Test stale downloaded book preserved after rescan
- [x] Test cache deleted for stale remote-only books
- [x] Test folder preserved for stale downloaded books

## Phase 6: Orphaned Cache Cleanup

### 6.1 Implement Orphan Detection
- [x] Implement `findOrphanedEntries(Set<String> validFolderIds)` in CacheManager
- [x] List all folder IDs in cache directory
- [x] Compare against valid folder IDs from database
- [x] Return list of orphaned folder IDs

### 6.2 Implement Orphan Deletion
- [x] Implement `cleanupOrphans(List<String> orphanedFolderIds)` in CacheManager
- [x] Delete cache directory for each orphaned folder ID
- [x] Count deleted entries
- [ ] Add error handling for deletion failures
- [x] Add logging for cleanup operations

### 6.3 Integrate Orphan Cleanup into Scan
- [x] Add `_cleanupOrphanedCache()` to DriveLibraryService
- [x] Call `_repo.getRemoteOnlyFolderIds()` to get valid folder IDs
- [x] Call `_cacheManager.findOrphanedEntries()` with valid IDs
- [x] Call `_cacheManager.cleanupOrphans()` with orphaned IDs
- [x] Call at end of `rescanDrive()`

### 6.4 Orphan Cleanup Tests
- [x] Test finding orphaned entries
- [x] Test deleting orphaned entries
- [x] Test preserving valid cache entries
- [x] Test logging of cleanup count
- [x] Test performance with 50+ orphaned entries

### 6.5 Integration Tests for Orphan Cleanup
- [x] Test orphaned cache deleted after scan
- [x] Test valid cache preserved after scan
- [x] Test cleanup count logged correctly

## Phase 7: Migration Safety

### 7.1 Implement Migration Detection
- [x] Add `_detectExistingDownloads()` to DriveLibraryService
- [x] Call during initialization (first scan after update)
- [x] List all folders in main audiobook directory
- [x] For each folder, check if book record exists in database
- [x] If record missing, create it with `isDownloaded=true`
- [x] If record exists but `isDownloaded=false`, update to `true`

### 7.2 Integrate Migration Detection
- [x] Call `_detectExistingDownloads()` at start of first `rescanDrive()` after update
- [x] Add flag to preferences to track if migration detection has run
- [x] Skip detection on subsequent scans

### 7.3 Migration Safety Tests
- [x] Test detecting existing folder without DB record
- [x] Test creating DB record for existing folder
- [x] Test updating isDownloaded flag for existing record
- [x] Test preserving folder contents
- [x] Test skipping detection after first run

### 7.4 Integration Tests for Migration Safety
- [x] Test existing folder preserved after update
- [x] Test book marked as downloaded after detection
- [x] Test no duplicate folders created
- [x] Test audio files remain playable

## Phase 8: Dependency Injection and Integration

### 8.1 Update Locator
- [x] Register `CacheManager` as singleton in `locator.dart`
- [x] Update `DriveLibraryService` constructor to accept `CacheManager`
- [x] Update `DriveDownloadManager` constructor to accept `CacheManager`
- [x] Update all service registrations in locator

### 8.2 Update UI Components
- [x] Update `_buildAudiobook()` in DriveLibraryService to check cache for covers
- [x] Update cover loading logic to try cache first, then folder
- [x] Update book details screen to show correct download status
- [x] Test UI displays correct state for remote vs downloaded books

### 8.3 End-to-End Integration Tests
- [x] Test complete workflow: scan → cache → download → migrate → cleanup
- [x] Test with multiple books simultaneously
- [x] Test with network interruptions
- [x] Test with storage space limitations
- [x] Test backward compatibility with existing installations

## Phase 9: Performance and Polish

### 9.1 Performance Optimization
- [x] Verify cache retrieval < 100ms (Requirement 2.5)
- [x] Optimize orphan cleanup for large cache directories
- [x] Add caching for frequently accessed metadata
- [x] Profile and optimize database queries

### 9.2 Error Handling and Logging
- [x] Review all error handling paths
- [x] Ensure all operations log appropriately
- [x] Add user-facing error messages where needed
- [x] Test error recovery scenarios

### 9.3 Documentation
- [x] Update code comments for modified components
- [x] Document cache directory structure
- [x] Document migration process
- [x] Add troubleshooting guide for common issues

### 9.4 Final Testing
- [x] Run all unit tests
- [x] Run all integration tests
- [x] Run performance tests
- [x] Test on multiple devices
- [x] Test with various Drive folder structures
- [x] Test migration from previous version
