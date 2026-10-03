# Contributing to SalahLK

Thanks for helping! Please read this and the [Code of Conduct](CODE_OF_CONDUCT.md).

## Branch model

| Branch | Purpose | Output |
|---|---|---|
| `main` | Production. Always releasable. Only receives merges from `stage`. | Tag `vX.Y.Z` → GitHub Release with APK |
| `stage` | Pre-release testing. Receives merges from `dev`. | Tag `vX.Y.Z-rc.N` → GitHub pre-release with APK |
| `dev` | Integration. Default target for PRs. | CI build artifact |
| `feature/*`, `fix/*` | Short-lived work branches, branched from `dev`. | CI only |

Flow: `feature/x` → PR → `dev` → PR → `stage` → PR → `main` → tag.
Hotfixes: branch `hotfix/*` from `main`, PR to `main`, then merge `main` back into `dev`.

## Commits
Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `ci:`.

## Versioning & releases
- SemVer in `pubspec.yaml` (`version: MAJOR.MINOR.PATCH+BUILD`); bump `BUILD` on every release.
- Update `CHANGELOG.md` under `[Unreleased]` in every user-facing PR.
- To release: move Unreleased entries to a new version heading, bump `pubspec.yaml`, merge to `main`, then
  `git tag vX.Y.Z && git push origin vX.Y.Z`. CI builds the APK and publishes the release.

## Before opening a PR
```
flutter pub get
dart format .
flutter analyze
flutter test
```
