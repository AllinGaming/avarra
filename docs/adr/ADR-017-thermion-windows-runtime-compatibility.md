# ADR-017 — Thermion Windows Runtime Compatibility

**Status:** Accepted interim dependency pin  
**Date:** 2026-08-10

## Context

ADR-016 selected published `thermion_flutter` 0.4.1 provisionally after both
product compile gates passed. A live Windows launch then proved why compiling
is not a sufficient renderer gate.

The first launch exposed an AVARRA integration defect: rebuilding
`ViewerWidget` constructed a new `DirectLight.sun()` object, which Thermion
rejects as an unsupported runtime configuration change. AVARRA now retains the
camera and direct-light objects for the full viewport State lifetime.

After that application fix, Thermion 0.4.1 still failed before loading the glTF
asset. Its Windows Vulkan/D3D external-texture worker and Filament render thread
both used Vulkan queue family 0. The NVIDIA RTX 3090 driver reported:

```text
vkQueueSubmit failed: -4
vkWaitForFences failed: -4
vkGetQueryPoolResults error=-4
```

`-4` is `VK_ERROR_DEVICE_LOST`. Windows recorded application error `0xc0000409`
in `ucrtbase.dll` and produced a crash dump. The failure was deterministic on
the validation machine.

## Upstream finding

Thermion's official `v0.5.0-pre.5` tag adds Windows queue coordination absent
from 0.4.1. It selects another queue from the graphics family when available.
When the hardware exposes only one queue, it serializes Filament and blit-worker
queue calls through a process-wide mutex.

The pre-release has not yet been published to pub.dev. AVARRA therefore tested
the exact tagged commit:

```text
caad37835e7d379621247b24b7de9d84071bd474
```

On the same machine, it selected `family 0, queue index 1`, remained responsive
for more than three minutes without device-loss, and completed a controlled
visible launch/close cycle within 15 seconds.

## Decision

Pin `thermion_flutter` and its `thermion_dart` dependency to official Thermion
commit `caad37835e7d379621247b24b7de9d84071bd474` (`v0.5.0-pre.5`). Keep the
Git dependency isolated to `avarra_thermion_bridge` and the root dependency
override. Do not vendor or patch Thermion native source into AVARRA.

Keep the Android compile-SDK workaround: the pre-release still declares
compile SDK 33 and uses the legacy Kotlin Gradle Plugin path.

## Verification

Passed with the exact commit:

- bridge and Game analysis;
- 3 bridge tests and 1 Game widget test;
- Game Windows release build;
- Game Android debug APK build;
- visible Windows process startup and sustained responsiveness;
- no `VK_ERROR_DEVICE_LOST` or unsupported widget update;
- controlled Windows close and process exit;
- Windows and Android packaging of all three cube asset files.

The first human visual inspection subsequently found an AVARRA fixture defect:
`Cube.gltf` referenced `Cube_BaseColor.png`, which had not been copied into the
asset directory. This was independent of the Vulkan compatibility decision.
AVARRA now packages the exact Khronos texture and tests that every external
buffer and image URI in the glTF resolves to a non-empty file.

The corrected Windows scene was visually confirmed on 2026-08-10. It preserved
the cube and HUD through resize and minimize/restore while the process remained
responsive. A Pixel 10 Pro Android emulator subsequently preserved the same
scene through three cold launches and five same-process background/resume
cycles with stable memory. A physical Android runtime/performance check remains
open, so Stage 2 is not yet complete.

## Consequences

- `flutter pub get` currently requires GitHub access in addition to pub.dev.
- The full commit hash makes the dependency immutable and reviewable.
- CI cold builds compile the newer native layer and may take longer.
- Move back to a published version when it contains the queue fix and passes
  the same Windows/Android compile and live runtime gates.
- Any future Thermion update must be deliberate; never widen this pin to a
  branch or floating pre-release constraint.

## Sources

- <https://pub.dev/packages/thermion_flutter>
- <https://github.com/nmfisher/thermion/tree/v0.5.0-pre.5>
- <https://github.com/nmfisher/thermion/blob/caad37835e7d379621247b24b7de9d84071bd474/thermion_dart/native/src/vulkan/windows/WindowsVulkanContext.cpp>
