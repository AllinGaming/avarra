import 'fixed_delta.dart';
import 'simulation_time.dart';
import 'tick_id.dart';

/// Immutable context for one fixed simulation update.
final class SimulationTick {
  const SimulationTick({
    required this.id,
    required this.fixedDelta,
    required this.simulationTime,
  });

  final TickId id;
  final FixedDelta fixedDelta;
  final SimulationTime simulationTime;
}
