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
