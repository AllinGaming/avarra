# AVARRA Android CI/CD Build Contract

**Status:** Android CI build verification implemented
**Date:** 2026-08-20

## Purpose

Avarra Game is the Android application. Forge remains a Windows desktop
creator application, and the dedicated server remains pure Dart.

Android packaging includes native Thermion/Filament compilation. It therefore
runs in its own GitHub Actions job instead of near the end of the combined
quality and Windows-build job. This gives Android its own timeout and makes a
native toolchain failure independent from the Windows application gates.

## Pinned CI toolchain

The workflow installs and uses:

| Tool | Version |
| --- | --- |
| Flutter | 3.44.4 stable |
| Dart | 3.12.2 through Flutter |
| Java | Temurin 17 |
| Android platform | 36 |
| Android build tools | 36.0.0 |
| Android NDK | 28.2.13676358 |
| CMake | 3.22.1 |
| Android Gradle Plugin | 9.0.1 |
| Gradle wrapper | 9.1.0 |

These values match the checked-in Flutter/Gradle project and the pinned
Thermion native build. Changing them is a build-system change and should be
verified with a clean APK build.

## CI command

The repository-owned `tool/build_android_ci.ps1` script is the single Android
build entry point for CI and local reproduction. From the repository root:

```powershell
.\tool\build_android_ci.ps1
```

The script requires Flutter 3.44.4 and Dart 3.12.2, requires Java 17 or newer,
installs and verifies the pinned Android SDK components, resolves workspace
dependencies, and runs `flutter build apk --debug --no-pub`. It then
requires
`apps/avarra_game/build/app/outputs/flutter-apk/app-debug.apk` to be a
non-empty file and logs its absolute path, byte length, and SHA-256 hash.

The Android job runs for pushes, pull requests, and manual
`workflow_dispatch` invocations. It does not wait for the Windows job,
so native compilation has a separate 45-minute budget.

## Local reproduction

Use the same Flutter release and Java 17, then run a clean reproduction from
the repository root:

```powershell
.\tool\build_android_ci.ps1 -Clean
```

For a routine repeat when the pinned SDK components are already installed:

```powershell
.\tool\build_android_ci.ps1 -SkipToolchainInstall
```

`-SkipToolchainInstall` skips only the sdkmanager install call. The script
still verifies every required component directory before dependency resolution
or compilation.

## Distribution and signing boundary

The CI job verifies compilation and packaging only. It does not upload the APK
or publish it to an external service.

The current Android release build falls back to the debug signing key for local
release-mode testing. It must not be distributed through an app store.
Production CD requires a separately approved workflow with:

- an application-owned keystore supplied through encrypted CI secrets;
- no signing key or password committed to the repository;
- a signed Android App Bundle or release APK;
- an explicit artifact destination and retention policy; and
- a manual/environment approval gate before store publication.

## Known upstream warning

The pinned Thermion Flutter plugin still applies the Kotlin Gradle Plugin.
Flutter 3.44.4 reports this as a future compatibility warning, not a build
failure. A future Flutter/AGP upgrade must either use an upstream Thermion
revision compatible with built-in Kotlin or record a measured compatibility
workaround. Do not silently remove the current compatibility flags.
