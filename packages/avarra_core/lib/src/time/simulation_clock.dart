import 'fixed_delta.dart';
import 'simulation_time.dart';

/// Simulation-owned clock advanced explicitly by fixed updates.
abstract interface class SimulationClock {
  SimulationTime get currentTime;

  void reset();

  void advance(FixedDelta delta);
}

/// Deterministic clock suitable for headless runtime and unit tests.
final class ManualSimulationClock implements SimulationClock {
  SimulationTime _currentTime = SimulationTime.zero;

  @override
  SimulationTime get currentTime => _currentTime;

  @override
  void reset() {
    _currentTime = SimulationTime.zero;
  }

  @override
  void advance(FixedDelta delta) {
    _currentTime = _currentTime.advance(delta);
  }
}
