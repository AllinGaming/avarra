# AVARRA Stage 12.35 - Android Kotlin Compatibility Validation

**Status:** Implemented and clean Android gate passes

**Date:** 2026-08-25

## Product outcome

AVARRA Game now builds its pinned Thermion Android plugin without Flutter's
future-incompatibility warning for plugins that apply the Kotlin Gradle Plugin
(KGP). The solution is checkout-local and reproducible in CI: it does not edit
the Pub cache, float the renderer dependency, or fork Thermion's Dart, Kotlin,
C++, or platform source.

## Implementation

- Game's `settings.gradle.kts` keeps the immutable Thermion project directory
  but redirects only its Gradle build file through Gradle's
  `ProjectDescriptor`;
- `android/gradle/thermion_flutter_compat.gradle` removes Thermion's embedded
  AGP 7.3/Kotlin 1.7 buildscript and `kotlin-android` application;
- the overlay uses AVARRA's Android API 36, NDK 28.2.13676358, Java 17, and
  `kotlin.compilerOptions` contract;
- the prior root-project `afterEvaluate` compile-SDK mutation is no longer
  required; and
- `tool/build_android_ci.ps1` captures Flutter build output and fails if the
  legacy-KGP warning returns.

## Boundary

This is an application build compatibility overlay, not an AVARRA renderer
fork. Thermion remains pinned to official commit
`caad37835e7d379621247b24b7de9d84071bd474`, and the scene bridge remains the
only runtime dependency boundary.

Flutter 3.44.4 currently keeps `android.builtInKotlin=false`; Flutter's
migration documentation requires Flutter 3.47 or later before enabling
built-in Kotlin. The source is migration-ready, but AVARRA does not silently
change that toolchain flag.

## Automated evidence

- a normal `flutter build apk --debug` passes without the KGP warning;
- `flutter clean` followed by a fresh `flutter build apk --debug` passes
  without the warning;
- `tool/build_android_ci.ps1 -SkipToolchainInstall` passes its new warning
  regression gate;
- the resulting debug APK is non-empty and hashed by the CI script; and
- the existing 340-test repository matrix and Windows/Server package gates
  remain unchanged by this Android-only build configuration.

## Removal condition

Remove the overlay only after a deliberately pinned upstream Thermion revision:

1. no longer applies KGP on AGP 9;
2. declares a compatible compile SDK and Java/Kotlin target;
3. passes AVARRA's Windows runtime and close gates;
4. passes clean Android packaging and emulator lifecycle checks; and
5. preserves the scene-bridge API used by Game and Forge.

## Sources

- <https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors>
- <https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers>
- <https://github.com/nmfisher/thermion/blob/develop/thermion_flutter/thermion_flutter/android/build.gradle>

