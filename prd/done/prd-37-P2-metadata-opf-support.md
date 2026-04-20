# PRD-37 (P2): metadata.opf support

## Problem
AudioVault reads book metadata exclusively from embedded audio tags. Many audiobook collections — particularly those managed by Calibre or downloaded from Audible/OverDrive — include a `metadata.opf` file in the book folder that carries richer, more accurate metadata: author, narrator, series, series index, description, publisher, language, and chapter/track titles. Ignoring this file means the library shows wrong or missing authors, no narrator info, and generic chapter names.

## Evidence
- `ScannerService` reads only embedded audio tags via `audio_metadata_reader`
- `Audiobook` model has no `narrator`, `series`, `seriesIndex`, or `description` fields
- Chapter names fall back to track titles from audio tags, which are often "Chapter 1", "Track 01", etc.
- Users with Calibre-managed libraries consistently see blank or incorrect author fields

## Proposed Solution
When scanning a book folder, check for a `metadata.opf` file. If present, parse it and use its values to fill or override the fields that audio tags provide poorly:

| OPF field | Maps to |
|---|---|
| `dc:title` | `Audiobook.title` |
| `dc:creator role="aut"` | `Audiobook.author` |
| `dc:creator role="nrt"` | `Audiobook.narrator` (new field) |
| `series` / `series-index` (Calibre custom meta) | `Audiobook.series`, `Audiobook.seriesIndex` (new fields) |
| `dc:description` | `Audiobook.description` (new field) |
| `dc:publisher` | `Audiobook.publisher` (new field) |
| `dc:language` | `Audiobook.language` (new field) |
| `opf:file-as` on creator | used as sort key, not displayed |

Chapter names from OPF are **not** used — chapter titles come from audio metadata (M4B chapter tracks or per-file track titles), which are more reliable for navigation.

OPF values take precedence over audio-tag values for the fields above. If OPF is absent or a field is missing, fall back to the existing audio-tag logic unchanged.

## Acceptance Criteria
- [ ] `ScannerService` detects `metadata.opf` in the book folder (case-insensitive filename match)
- [ ] Author field is populated from OPF `dc:creator role="aut"` when present
- [ ] Narrator, series, seriesIndex, description, publisher, language fields are populated when present in OPF
- [ ] New fields are displayed in the Book Details sheet
- [ ] Narrator shown in the Player screen subtitle when available (replacing or appending to author)
- [ ] Series + index shown in Book Details sheet
- [ ] Existing books without OPF are unaffected
- [ ] Unit tests cover OPF parsing for all mapped fields, missing fields, and malformed XML

## Out of Scope
- Writing back to OPF
- Parsing OPF cover art (existing cover logic is sufficient)
- Chapter names from OPF (audio metadata is used for navigation)
- EPUB OPF support (audiobook folders only)

## Implementation Plan
1. Add fields to `Audiobook`: `narrator`, `series`, `seriesIndex` (int?), `description`, `publisher`, `language` — all nullable.
2. Create `lib/services/opf_parser.dart` — a pure function `OpfMetadata parseOpf(String xmlContent)` returning a simple value object with the mapped fields. Use `dart:convert` / `xml` package (already available via transitive deps; add `xml` to pubspec if not present).
3. In `ScannerService._scanBookFolder()` (or equivalent), after collecting audio files, check for `metadata.opf` (case-insensitive). If found, read and parse it, then merge into the `Audiobook` being constructed — OPF values win for the listed fields.
4. Update `BookDetailsScreen` to show narrator, series (with index), description, publisher, language when non-null.
5. Update `PlayerScreen` subtitle: if `narrator` is non-null, show "Read by [narrator]" below the title; otherwise show author as today.
6. Unit tests in `test/services/opf_parser_test.dart`:
   - Full OPF with all fields → all fields populated
   - OPF with only `dc:title` and `dc:creator` → other fields null
   - Malformed XML → returns empty `OpfMetadata` without throwing
   - Multiple creators with different roles → correct role assignment
7. Integration smoke test: scan a fixture folder containing a minimal `metadata.opf` and assert the returned `Audiobook` has the expected author/narrator.

## Files Impacted
- `lib/models/audiobook.dart` (new fields)
- `lib/services/scanner_service.dart` (OPF detection + merge)
- `lib/services/opf_parser.dart` (new)
- `lib/screens/book_details_screen.dart` (display new fields)
- `lib/screens/player_screen.dart` (narrator subtitle)
- `pubspec.yaml` (add `xml` package if not already present)
- `test/services/opf_parser_test.dart` (new)
- `CHANGELOG.md`
