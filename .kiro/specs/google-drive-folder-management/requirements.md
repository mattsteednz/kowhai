# Requirements Document

## Introduction

This feature addresses folder and cache management issues for Google Drive audiobooks in the Kōwhai application. Currently, the system creates folders prematurely during scanning, stores metadata in incorrect locations, and fails to clean up stale or orphaned data. This enhancement ensures folders are created only when needed, metadata is cached appropriately, and cleanup operations maintain data consistency.

## Glossary

- **Google_Drive_Scanner**: The component responsible for scanning and discovering audiobooks from Google Drive
- **Audiobook_Downloader**: The component responsible for downloading audiobook files from Google Drive to local storage
- **Folder_Manager**: The component responsible for creating and managing audiobook folders in the main audiobook directory
- **Cache_Manager**: The component responsible for storing and retrieving metadata and covers in app storage space
- **Main_Audiobook_Directory**: The primary directory where downloaded audiobook folders are stored
- **App_Storage_Space**: The application's internal storage area for caching metadata and covers
- **Remote_Book**: An audiobook that exists in Google Drive but has not been downloaded locally
- **Downloaded_Book**: An audiobook that has been downloaded from Google Drive to local storage
- **Stale_Book**: A book entry that exists locally but no longer exists in Google Drive
- **Orphaned_Cache**: Metadata or cover files stored in app storage that no longer have a corresponding remote book

## Requirements

### Requirement 1: Folder Creation Timing

**User Story:** As a user, I want audiobook folders created only when I download books, so that my audiobook directory doesn't contain empty folders for books I haven't downloaded.

#### Acceptance Criteria

1. WHEN THE Google_Drive_Scanner scans for audiobooks, THE Folder_Manager SHALL NOT create folders in the Main_Audiobook_Directory
2. WHEN THE Audiobook_Downloader downloads a Google Drive audiobook, THE Folder_Manager SHALL create a folder in the Main_Audiobook_Directory
3. WHEN THE Audiobook_Downloader completes a download, THE Folder_Manager SHALL verify the folder exists before storing audiobook files
4. FOR ALL Remote_Books that are not Downloaded_Books, THE Main_Audiobook_Directory SHALL NOT contain corresponding folders

### Requirement 2: Metadata and Cover Caching

**User Story:** As a user, I want metadata and covers for non-downloaded books cached in app storage, so that I can browse book information without cluttering my audiobook directory.

#### Acceptance Criteria

1. WHEN THE Google_Drive_Scanner discovers a Remote_Book, THE Cache_Manager SHALL store metadata in the App_Storage_Space
2. WHEN THE Google_Drive_Scanner discovers a Remote_Book with cover art, THE Cache_Manager SHALL store the cover in the App_Storage_Space
3. WHEN a Remote_Book becomes a Downloaded_Book, THE Audiobook_Downloader SHALL download all audio files to the Main_Audiobook_Directory folder AND THE Cache_Manager SHALL migrate metadata and cover to the same folder, creating a fully self-contained package
4. THE Cache_Manager SHALL organize cached data by unique book identifier to prevent collisions
5. WHEN the application requests metadata for a Remote_Book, THE Cache_Manager SHALL retrieve it from the App_Storage_Space within 100ms

### Requirement 3: Stale Book Cleanup

**User Story:** As a user, I want non-downloaded books removed from Google Drive to be removed from my local library, so that my library accurately reflects what's available remotely, while preserving books I've already downloaded.

#### Acceptance Criteria

1. WHEN THE Google_Drive_Scanner completes a scan, THE Google_Drive_Scanner SHALL identify all Stale_Books that are Remote_Books only
2. WHEN a Stale_Book is identified AND it is NOT a Downloaded_Book, THE Google_Drive_Scanner SHALL remove the book entry from the local library database
3. WHEN a Stale_Book is identified AND it IS a Downloaded_Book, THE Google_Drive_Scanner SHALL preserve the book entry and its folder in the Main_Audiobook_Directory
4. WHEN THE Google_Drive_Scanner removes a Stale_Book that is a Remote_Book, THE Cache_Manager SHALL delete associated cached metadata and covers from the App_Storage_Space
5. THE Google_Drive_Scanner SHALL log all removed Stale_Books for user visibility

### Requirement 4: Orphaned Cache Cleanup

**User Story:** As a developer, I want orphaned cache files removed during scans, so that app storage doesn't accumulate unnecessary data over time.

#### Acceptance Criteria

1. WHEN THE Google_Drive_Scanner completes a scan, THE Cache_Manager SHALL identify all Orphaned_Cache entries
2. WHEN an Orphaned_Cache entry is identified, THE Cache_Manager SHALL delete the metadata file from the App_Storage_Space
3. WHEN an Orphaned_Cache entry is identified, THE Cache_Manager SHALL delete the cover file from the App_Storage_Space
4. THE Cache_Manager SHALL compare cached entries against the current list of Remote_Books to determine orphaned status
5. THE Cache_Manager SHALL log the count of deleted Orphaned_Cache entries for monitoring purposes

### Requirement 5: Migration Safety

**User Story:** As a user, I want my existing downloaded books to remain intact during the migration, so that I don't lose any data or have to re-download content.

#### Acceptance Criteria

1. WHEN the updated system initializes, THE Folder_Manager SHALL identify all existing folders in the Main_Audiobook_Directory
2. WHEN an existing folder is identified, THE Folder_Manager SHALL mark the corresponding book as a Downloaded_Book
3. IF an existing folder contains metadata or covers, THEN THE Cache_Manager SHALL NOT duplicate them in the App_Storage_Space
4. THE Folder_Manager SHALL preserve all existing folder structures and file contents during migration
5. WHEN migration completes, THE Folder_Manager SHALL verify that all previously Downloaded_Books remain accessible
