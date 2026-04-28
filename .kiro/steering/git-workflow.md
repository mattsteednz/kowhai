# Git Workflow

- Default branch: `main`
- Never commit new code directly to `main` — always create a branch first
- Exception: rules, config, and documentation-only changes may be committed directly to `main`
- **Always branch from `main`, never from another feature branch** — this prevents PR chaining and allows independent merges
- Create a new branch for each feature or fix: `git checkout -b <type>/<short-description>`
  - Types: `feature/`, `fix/`, `security/`, `chore/`, `docs/`
  - For PRD-tracked features: `feature/prd-{number}-{description}` (e.g. `feature/prd-7-metadata-enrichment`)
- Keep commits focused; write descriptive commit messages in the format `type(scope): short description`
  - Types: `feat`, `fix`, `security`, `chore`, `refactor`, `docs`, `test`
  - Example: `feat(player): add sleep timer`, `fix(library): chapter index off-by-one`
- Merge via squash merge only; no merge commits on `main`
- **Before every `git commit`**, run both `flutter analyze --fatal-warnings` and `flutter test` locally. Both must pass with zero errors and zero warnings. Do not commit if either fails — fix the issues first. This is non-negotiable.
- Any new code that can be unit tested must have a corresponding test before merging
- Before merging to `main`, update `CHANGELOG.md` and `README.md` with any relevant changes

## Merge Flow

1. **Start new work from main:**
   ```bash
   git checkout main && git pull origin main
   git checkout -b <type>/<description>
   ```

2. **Before pushing, rebase from main:**
   ```bash
   git fetch origin
   git rebase origin/main
   # Resolve any conflicts, then:
   git push -u origin <branch> --force-with-lease
   ```

3. **Create PR with auto-merge:**
   ```bash
   gh pr create --title "..." --body "..." --base main
   gh pr merge <number> --auto --squash
   ```

4. **CI validates:** `flutter analyze --fatal-warnings` and `flutter test` run automatically

5. **Auto-merge on green:** GitHub squash-merges to `main` and deletes the branch when CI passes

6. **Pull main locally:**
   ```bash
   git checkout main && git pull origin main
   ```

## Branch Strategy

- **Always branch from main, never from another feature branch** — prevents PR chaining and allows all PRs to merge independently
- Each PR is independent and can merge in any order without blocking others
- If multiple PRs are in flight and main updates, rebase each one:
  ```bash
  git fetch origin
  git rebase origin/main
  git push --force-with-lease
  ```
- This keeps history linear and avoids merge conflicts between feature branches

## Bug Fix Routing

| Bug type | Branch | Merge target |
|---|---|---|
| Critical/hotfix | Commit directly to `main` | `main` |
| Related to open feature branch | Fix in that feature branch | Included in feature squash |
| Standalone | `fix/{description}` | PR → `main` |
