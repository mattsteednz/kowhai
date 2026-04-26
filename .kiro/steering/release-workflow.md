---
inclusion: manual
---

# Release & Publishing Workflow

## Version Scheme

`pubspec.yaml` uses `MAJOR.MINOR.PATCH+BUILD`.

| Change level | Examples | Version bump |
|---|---|---|
| **minor** | New user-facing feature | `1.2.x+n` → `1.3.0+n+1` |
| **patch** | Bug fix, polish, minor enhancement | `1.2.3+n` → `1.2.4+n+1` |
| **major** | Breaking change, full redesign | `1.x.y+n` → `2.0.0+n+1` |

Always increment BUILD by 1 regardless of semver level.

## Feature Completion Checklist (`/complete`)

Run when a feature branch is ready to merge.

1. **Review scope** — `git log --oneline main..HEAD` to summarise what changed; classify as minor or patch
2. **Check for missing tests** — any new service methods or non-trivial logic needs a test in `test/`; UI widgets and platform calls are exempt
3. **Analyze** — `flutter analyze --fatal-warnings` — fix all issues
4. **Test** — `flutter test` — all must pass
5. **Update CHANGELOG.md** — add entry under `## [Unreleased]` or new versioned section
6. **Update README.md** — update Features list, Tech Stack table, or Project Structure if affected
7. **Bump version** in `pubspec.yaml`
8. **Commit** — `git add -A && git commit -m "chore: bump to X.Y.Z, update CHANGELOG and README"`
9. **Merge via PR** — follow the standard merge flow in git-workflow.md

## GitHub Release (`/release`)

Run when `main` is ready to ship publicly.

1. Ensure on latest main: `git checkout main && git pull origin main`
2. Assess change level by reading CHANGELOG and recent commits
3. Bump version in `pubspec.yaml`
4. Update `CHANGELOG.md` — replace `## [Unreleased]` with versioned entry
5. Update `README.md` — Features, Tech Stack, Project Structure
6. Run `flutter analyze --fatal-warnings && flutter test` — fix any failures
7. Commit: `git add pubspec.yaml CHANGELOG.md README.md && git commit -m "chore: bump to X.Y.Z, update CHANGELOG and README"` then `git push origin main`
8. Build release APK: `flutter build apk --release`
9. Rename APK: `cp build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/audiovault-X.Y.Z.apk`
10. Create GitHub release:
    ```bash
    gh release create vX.Y.Z \
      "build/app/outputs/flutter-apk/audiovault-X.Y.Z.apk#audiovault-X.Y.Z.apk" \
      --title "AudioVault X.Y.Z" \
      --notes "<notes from CHANGELOG entry>"
    ```
    Add footer: `---\n[Full changelog](https://github.com/mattsteednz/audiovault/blob/main/CHANGELOG.md)`

## Debug APK Deploy (`/publish-debug`)

1. `git checkout main && git pull origin main`
2. `flutter build apk --debug`
3. `node deploy.mjs --build --debug` — reads SFTP credentials from `.env`, uploads to remote releases folder
4. Confirm version deployed (from `pubspec.yaml`) and upload succeeded
