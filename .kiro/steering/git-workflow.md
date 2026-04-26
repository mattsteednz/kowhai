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

1. **Rebase from main before pushing:**
   ```bash
   git checkout main && git pull origin main
   git checkout <branch>
   git rebase main
   # Resolve any conflicts, then:
   git push -u origin <branch> --force-with-lease
   ```
2. **Create PR with auto-merge:**
   ```bash
   gh pr create --title "..." --body "..." --base main
   gh pr merge <number> --auto --squash
   ```
3. **CI validates:** `flutter analyze --fatal-warnings` and `flutter test` run automatically
4. **Auto-merge on green:** GitHub squash-merges to `main` and deletes the branch when CI passes
5. **Pull main locally:**
   ```bash
   git checkout main && git pull origin main
   ```

## Rebase Strategy

- **Always rebase from main before pushing** to avoid merge conflicts and keep history linear
- Use `--force-with-lease` (not `--force`) when pushing after rebase to protect against accidental overwrites
- If CI fails after rebase, fix locally, commit, and push again (no need to recreate PR)
- For long-running branches, rebase from main frequently (daily or before each push) to minimize conflict resolution

## Bug Fix Routing

| Bug type | Branch | Merge target |
|---|---|---|
| Critical/hotfix | Commit directly to `main` | `main` |
| Related to open feature branch | Fix in that feature branch | Included in feature squash |
| Standalone | `fix/{description}` | PR → `main` |
