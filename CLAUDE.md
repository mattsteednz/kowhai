# Git Workflow

- Default branch: `main`
- Never commit new code directly to `main` — always create a branch first
- Exception: rules, config, and documentation-only changes may be committed directly to `main`
- Create a new branch for each feature or fix: `git checkout -b <type>/<short-description>`
  - Types: `feature/`, `fix/`, `security/`, `chore/`
- Keep commits focused; write descriptive commit messages in the format `type: short description`
  - Use the same types as branch prefixes: `feat`, `fix`, `security`, `chore`
  - Example: `feat: add sleep timer`, `fix: chapter index off-by-one`
- Merge via squash merge only; no merge commits on `main`
- Before pushing a branch, run `flutter analyze --fatal-warnings` and `flutter test` locally and confirm both pass — errors and warnings are not acceptable
- Any new code on a feature branch that can be unit tested must have a corresponding test before merging — if it's testable, it's tested
- Before merging to `main`, update CHANGELOG.md and README.md with any relevant changes
- **Merge flow (solo dev):**
  1. Push branch: `git push -u origin <branch>`
  2. Create PR with auto-merge enabled: `gh pr create --title "..." --body "..." --base main` then `gh pr merge <number> --auto --squash`
  3. CI runs `flutter analyze --fatal-warnings` and `flutter test` automatically
  4. On green, GitHub squash-merges to `main` and deletes the branch automatically
  5. Pull main locally: `git checkout main && git pull origin main`
