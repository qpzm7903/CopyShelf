# Project workflow

Before planning or implementing a version, read these files in order:

1. `CONTEXT.md` for the product language and hard boundaries.
2. `plan.md` for the current release baseline and candidate scope.
3. `docs/maintenance.md` for priority, Definition of Done, Windows validation, and release rules.

Start each iteration by checking open GitHub Issues and recent CI runs. Security, data integrity, broken releases, and verified regressions take priority over roadmap features.

Keep `plan.md` current as scope or status changes. Add an ADR for changes to data format, sync semantics, privacy boundaries, or platform architecture. Do not put snippet content, clipboard content, credentials, or private repository addresses in logs, fixtures, issues, or commits.

Local quality gates are:

```bash
export PATH="$HOME/sdks/flutter-stable/bin:$PATH"
flutter analyze --no-fatal-infos
flutter test
git diff --check
```

CopyShelf is Windows-only. Record any affected Windows paths that were not verified locally; do not represent widget tests as Win32 end-to-end coverage. Do not create or push a release tag unless the user explicitly requests a release.
