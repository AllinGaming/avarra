import 'package:avarra_world/avarra_world.dart';

import 'creator_command.dart';
import 'creator_validation.dart';

final class CreatorCommandRecord {
  const CreatorCommandRecord({required this.toolId, required this.description});

  final String toolId;
  final String description;
}

final class _HistoryEntry {
  const _HistoryEntry({
    required this.command,
    required this.before,
    required this.after,
  });

  final CreatorCommandRecord command;
  final WorldDefinition before;
  final WorldDefinition after;
}

/// Canonical editable world state behind Forge human and future agent actions.
final class CreatorWorldSession {
  CreatorWorldSession({
    required WorldDefinition initialWorld,
    CreatorWorldValidator? validator,
    WorldPackageCodec? codec,
  }) : _world = initialWorld,
       _validator = validator ?? CreatorWorldValidator(codec: codec),
       _codec = codec ?? WorldPackageCodec() {
    _validator.validate(initialWorld).throwIfInvalid();
    _savedSource = _codec.encodeCanonical(initialWorld);
  }

  final CreatorWorldValidator _validator;
  final WorldPackageCodec _codec;
  final List<_HistoryEntry> _undo = [];
  final List<_HistoryEntry> _redo = [];
  late String _savedSource;
  WorldDefinition _world;
  int _revision = 0;

  WorldDefinition get world => _world;
  int get revision => _revision;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isDirty => _codec.encodeCanonical(_world) != _savedSource;

  List<CreatorCommandRecord> get undoHistory =>
      List.unmodifiable(_undo.map((entry) => entry.command));

  void execute(CreatorCommand command) {
    final next = command.apply(_world);
    _validator.validate(next).throwIfInvalid();
    final record = CreatorCommandRecord(
      toolId: command.toolId,
      description: command.description,
    );
    _undo.add(_HistoryEntry(command: record, before: _world, after: next));
    _redo.clear();
    _world = next;
    _revision += 1;
  }

  bool undo() {
    if (_undo.isEmpty) {
      return false;
    }
    final entry = _undo.removeLast();
    _redo.add(entry);
    _world = entry.before;
    _revision += 1;
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) {
      return false;
    }
    final entry = _redo.removeLast();
    _undo.add(entry);
    _world = entry.after;
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
}
