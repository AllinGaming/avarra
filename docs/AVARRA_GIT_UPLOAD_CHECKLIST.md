# AVARRA Git Upload Checklist

**Status:** Maintainer checklist

**Date:** 2026-08-14

Use this checklist from the repository root before publishing a branch.

## Verification

```powershell
flutter pub get
dart analyze .
dart test packages/avarra_core
# Run the remaining package/app tests listed in README.md.
git status --short
git diff --check
```

Build outputs, Dart/Flutter caches, logs, Android intermediates, editor state,
and symbol/map artifacts are excluded by `.gitignore`. Do not add application
support saves, device captures, signing keys, API keys, or local environment
files.

## Review the commit

```powershell
git diff --stat HEAD
git diff HEAD
git log -1 --oneline
```

Confirm that generated `AVARRA_MASTER_LLM_HANDOFF_v8.md` matches its source
documents by running:

```powershell
powershell -ExecutionPolicy Bypass -File tool/build_master_handoff.ps1
git status --short
```

## Publish

After creating an empty remote repository, substitute its URL below:

```powershell
git remote add origin <repository-url>
git push -u origin HEAD
```

If `origin` already exists, inspect it before changing anything:

```powershell
git remote -v
git push -u origin HEAD
```

Never commit credentials to make a push work. Authenticate with the Git host's
credential manager, SSH agent, or approved CLI instead.
