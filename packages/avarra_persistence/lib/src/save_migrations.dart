import 'dart:convert';

import 'package:avarra_core/avarra_core.dart';

import 'persistence_error_codes.dart';
import 'save_models.dart';

abstract interface class SaveMigration {
  int get fromVersion;
  int get toVersion;
  Map<String, dynamic> migrate(Map<String, dynamic> source);
}

/// Sequential registry skeleton for future save-format migrations.
final class SaveMigrationRegistry {
  SaveMigrationRegistry({
    Iterable<SaveMigration> migrations = const [],
    this.targetVersion = currentSaveFormatVersion,
  }) : _migrations = Map.unmodifiable({
         for (final migration in _builtInSaveMigrations)
           migration.fromVersion: migration,
         for (final migration in migrations) migration.fromVersion: migration,
       });

  final int targetVersion;
  final Map<int, SaveMigration> _migrations;

  Map<String, dynamic> migrate(Map<String, dynamic> source) {
    final version = source['saveFormatVersion'];
    if (version is! int || version < 0 || version > targetVersion) {
      _unsupported(version);
    }
    var current = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
    var currentVersion = version;
    while (currentVersion < targetVersion) {
      final migration = _migrations[currentVersion];
      if (migration == null || migration.toVersion != currentVersion + 1) {
        _unsupported(currentVersion);
      }
      current = migration.migrate(current);
      if (current['saveFormatVersion'] != migration.toVersion) {
        throw AvarraException(
          code: PersistenceErrorCodes.invalidSaveData,
          message: 'A save migration did not declare its target version.',
        );
      }
      currentVersion = migration.toVersion;
    }
    return current;
  }

  Never _unsupported(Object? version) {
    throw AvarraException(
      code: PersistenceErrorCodes.unsupportedSaveVersion,
      message: 'The save format version is not supported.',
      context: {'version': version, 'targetVersion': targetVersion},
    );
  }
}

const List<SaveMigration> _builtInSaveMigrations = [SaveFormat1To2()];

/// Adds the player-owned single-quantity inventory introduced by Stage 11.4.
final class SaveFormat1To2 implements SaveMigration {
  const SaveFormat1To2();

  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 2;

  @override
  Map<String, dynamic> migrate(Map<String, dynamic> source) {
    final players = source['players'];
    if (players is! List<dynamic>) {
      throw AvarraException(
        code: PersistenceErrorCodes.invalidSaveData,
        message: 'Save players must be a list before inventory migration.',
      );
    }
    return {
      ...source,
      'saveFormatVersion': 2,
      'players': [
        for (final player in players)
          if (player is Map<String, dynamic>)
            {...player, 'inventoryItemIds': <String>[]}
          else
            player,
      ],
    };
  }
}
