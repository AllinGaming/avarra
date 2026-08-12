import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';

import 'creator_command.dart';
import 'creator_error_codes.dart';
import 'creator_validation.dart';

final class CreatorCommandRecord {
  const CreatorCommandRecord({required this.toolId, required this.description});

  final String toolId;
  final String description;
}

/// Deterministic cap for the command and inverse data retained by a session.
final class CreatorHistoryBudget {
  const CreatorHistoryBudget({
    this.maximumEntries = 100,
    this.maximumEstimatedBytes = 1024 * 1024,
  }) : assert(maximumEntries > 0),
       assert(maximumEstimatedBytes > 0);

  final int maximumEntries;
  final int maximumEstimatedBytes;
}

final class _HistoryEntry {
  const _HistoryEntry({
    required this.command,
    required this.forward,
    required this.inverse,
    required this.estimatedBytes,
  });

  final CreatorCommandRecord command;
  final CreatorCommand forward;
  final CreatorCommand inverse;
  final int estimatedBytes;
}

/// Canonical editable world state behind Forge human and future agent actions.
final class CreatorWorldSession {
  CreatorWorldSession({
    required WorldDefinition initialWorld,
    CreatorWorldValidator? validator,
    WorldPackageCodec? codec,
    this.historyBudget = const CreatorHistoryBudget(),
  }) : _world = initialWorld,
       _validator = validator ?? CreatorWorldValidator(codec: codec),
       _codec = codec ?? WorldPackageCodec() {
    _validator.validate(initialWorld).throwIfInvalid();
    _savedSource = _codec.encodeCanonical(initialWorld);
  }

  final CreatorWorldValidator _validator;
  final WorldPackageCodec _codec;
  final CreatorHistoryBudget historyBudget;
  final List<_HistoryEntry> _undo = [];
  final List<_HistoryEntry> _redo = [];
  late String _savedSource;
  WorldDefinition _world;
  int _revision = 0;
  int _historyEstimatedBytes = 0;
  int _discardedHistoryEntryCount = 0;

  WorldDefinition get world => _world;
  int get revision => _revision;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isDirty => _codec.encodeCanonical(_world) != _savedSource;
  int get historyEstimatedBytes => _historyEstimatedBytes;
  int get discardedHistoryEntryCount => _discardedHistoryEntryCount;

  List<CreatorCommandRecord> get undoHistory =>
      List.unmodifiable(_undo.map((entry) => entry.command));

  void execute(CreatorCommand command) {
    final inverse = command.inverseFor(_world);
    final next = command.apply(_world);
    _validator.validate(next).throwIfInvalid();
    final record = CreatorCommandRecord(
      toolId: command.toolId,
      description: command.description,
    );
    final estimatedBytes =
        64 + command.estimatedHistoryBytes + inverse.estimatedHistoryBytes;
    if (estimatedBytes > historyBudget.maximumEstimatedBytes) {
      throw AvarraException(
        code: CreatorErrorCodes.historyBudgetExceeded,
        message:
            'The creator command is too large for the configured undo budget.',
        context: {
          'estimatedBytes': estimatedBytes,
          'maximumEstimatedBytes': historyBudget.maximumEstimatedBytes,
        },
      );
    }
    for (final entry in _redo) {
      _historyEstimatedBytes -= entry.estimatedBytes;
    }
    _redo.clear();
    _undo.add(
      _HistoryEntry(
        command: record,
        forward: command,
        inverse: inverse,
        estimatedBytes: estimatedBytes,
      ),
    );
    _historyEstimatedBytes += estimatedBytes;
    _trimHistoryToBudget();
    _world = next;
    _revision += 1;
  }

  bool undo() {
    if (_undo.isEmpty) {
      return false;
    }
    final entry = _undo.removeLast();
    final next = entry.inverse.apply(_world);
    _validator.validate(next).throwIfInvalid();
    _redo.add(entry);
    _world = next;
    _revision += 1;
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) {
      return false;
    }
    final entry = _redo.removeLast();
    final next = entry.forward.apply(_world);
    _validator.validate(next).throwIfInvalid();
    _undo.add(entry);
    _world = next;
    _revision += 1;
    return true;
  }

  CreatorValidationReport validate({bool requirePlayableEntry = false}) {
    return _validator.validate(
      _world,
      requirePlayableEntry: requirePlayableEntry,
    );
  }

  String exportCanonical() {
    validate(requirePlayableEntry: true).throwIfInvalid();
    return _codec.encodeCanonical(_world);
  }

  void markSaved({String? exportedSource}) {
    _savedSource = exportedSource ?? _codec.encodeCanonical(_world);
  }

  void _trimHistoryToBudget() {
    while (_undo.length > historyBudget.maximumEntries ||
        _historyEstimatedBytes > historyBudget.maximumEstimatedBytes) {
      final discarded = _undo.removeAt(0);
      _historyEstimatedBytes -= discarded.estimatedBytes;
      _discardedHistoryEntryCount += 1;
    }
  }
}
