# Git Workflow

- Default branch: `main`
- Never commit new code directly to `main` — always create a branch first
- Exception: rules, config, and documentation-only changes may be committed directly to `main`
- Create a new branch for each feature or fix: `git checkout -b <type>/<short-description>`
  - Types: `feature/`, `fix/`, `security/`, `chore/`
  - For PRD-tracked features: `feature/prd-{number}-{description}` (e.g. `feature/prd-7-metadata-enrichment`)
- Keep commits focused; write descriptive commit messages in the format `type(scope): short description`
  - Types: `feat`, `fix`, `security`, `chore`, `refactor`, `docs`, `test`
  - Example: `feat(player): add sleep timer`, `fix(library): chapter index off-by-one`
- Merge via squash merge only; no merge commits on `main`
- Before pushing a branch, run `flutter analyze --fatal-warnings` and `flutter test` locally — errors and warnings are not acceptable
- Any new code that can be unit tested must have a corresponding test before merging
- Before merging to `main`, update `CHANGELOG.md` and `README.md` with any relevant changes

## Merge Flow

1. Push branch: `git push -u origin <branch>`
2. Create PR with auto-merge enabled:
   ```bash
   gh pr create --title "..." --body "..." --base main
   gh pr merge <number> --auto --squash
   ```
3. CI runs `flutter analyze --fatal-warnings` and `flutter test` automatically
4. On green, GitHub squash-merges to `main` and deletes the branch automatically
5. Pull main locally: `git checkout main && git pull origin main`

## Bug Fix Routing

| Bug type | Branch | Merge target |
|---|---|---|
| Critical/hotfix | Commit directly to `main` | `main` |
| Related to open feature branch | Fix in that feature branch | Included in feature squash |
| Standalone | `fix/{description}` | PR → `main` |
