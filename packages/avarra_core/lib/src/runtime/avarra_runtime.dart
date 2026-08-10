import '../errors/avarra_error.dart';
import '../logging/avarra_logger.dart';
import '../time/fixed_delta.dart';
import '../time/simulation_clock.dart';
import '../time/simulation_tick.dart';
import '../time/simulation_time.dart';
import '../time/tick_id.dart';

enum RuntimeLifecycleState { created, initialized, running, stopped }

/// Minimal deterministic lifecycle for AVARRA simulation packages.
final class AvarraRuntime {
  AvarraRuntime({
    required this.fixedDelta,
    this.logger = const NullAvarraLogger(),
    SimulationClock? clock,
  }) : _clock = clock ?? ManualSimulationClock();

  final FixedDelta fixedDelta;
  final AvarraLogger logger;
  final SimulationClock _clock;

  RuntimeLifecycleState _state = RuntimeLifecycleState.created;
  TickId _nextTickId = TickId.zero;

  RuntimeLifecycleState get state => _state;
  int get completedTickCount => _nextTickId.value;
  SimulationTime get simulationTime => _clock.currentTime;

  void initialize() {
    _requireState(RuntimeLifecycleState.created, 'initialize');
    _clock.reset();
    _nextTickId = TickId.zero;
    _state = RuntimeLifecycleState.initialized;
    logger.log(
      AvarraLogRecord(
        level: AvarraLogLevel.info,
        event: 'core.runtime.initialized',
        message: 'Simulation runtime initialized.',
        fields: {'fixedDeltaMicroseconds': fixedDelta.inMicroseconds},
      ),
    );
  }

  void start() {
    _requireState(RuntimeLifecycleState.initialized, 'start');
    _state = RuntimeLifecycleState.running;
    logger.log(
      AvarraLogRecord(
        level: AvarraLogLevel.info,
        event: 'core.runtime.started',
        message: 'Simulation runtime started.',
      ),
    );
  }

  SimulationTick tick() {
    _requireState(RuntimeLifecycleState.running, 'tick');
    final tick = SimulationTick(
      id: _nextTickId,
      fixedDelta: fixedDelta,
      simulationTime: _clock.currentTime,
    );
    _clock.advance(fixedDelta);
    _nextTickId = _nextTickId.next();
    return tick;
  }

  void stop() {
    _requireState(RuntimeLifecycleState.running, 'stop');
    _state = RuntimeLifecycleState.stopped;
    logger.log(
      AvarraLogRecord(
        level: AvarraLogLevel.info,
        event: 'core.runtime.stopped',
        message: 'Simulation runtime stopped.',
        fields: {
          'completedTicks': completedTickCount,
          'simulationTimeMicroseconds': simulationTime.inMicroseconds,
        },
      ),
    );
  }

  void _requireState(RuntimeLifecycleState expected, String operation) {
    if (_state == expected) {
      return;
    }

    throw AvarraException(
      code: AvarraErrorCode.invalidRuntimeState,
      message: 'Cannot $operation runtime while state is ${_state.name}.',
      context: {
        'operation': operation,
        'expectedState': expected.name,
        'actualState': _state.name,
      },
    );
  }
}
