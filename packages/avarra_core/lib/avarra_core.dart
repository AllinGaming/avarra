export 'src/errors/avarra_error.dart';
export 'src/identity/stable_id.dart';
export 'src/logging/avarra_logger.dart';
export 'src/runtime/avarra_runtime.dart';
export 'src/time/fixed_delta.dart';
export 'src/time/simulation_clock.dart';
export 'src/time/simulation_tick.dart';
export 'src/time/simulation_time.dart';
export 'src/time/tick_id.dart';

/// Canonical product name shared by AVARRA applications.
const String avarraProductName = 'AVARRA';

/// Process argument used by Forge to launch Game with one disposable package.
const String avarraForgeTestPlayArgumentPrefix = '--avarra-forge-test-play=';

/// Architecture generation implemented by this repository foundation.
const String avarraArchitectureGeneration = 'v8-reviewed';
