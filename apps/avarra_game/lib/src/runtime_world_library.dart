import 'dart:convert';
import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';

typedef WorldAssetAvailability = Future<bool> Function(String assetPath);

abstract final class RuntimeWorldLibraryErrorCodes {
  static const sourceTooLarge = AvarraErrorCode(
    'GAME_WORLD_IMPORT_SOURCE_TOO_LARGE',
  );
  static const assetUnavailable = AvarraErrorCode(
    'GAME_WORLD_IMPORT_ASSET_UNAVAILABLE',
  );
  static const storageFailure = AvarraErrorCode(
    'GAME_WORLD_LIBRARY_STORAGE_FAILURE',
  );
  static const selectionInvalid = AvarraErrorCode(
    'GAME_WORLD_LIBRARY_SELECTION_INVALID',
  );
}

final class RuntimeWorldLibraryEntry {
  const RuntimeWorldLibraryEntry({
    required this.worldId,
    required this.name,
    required this.source,
    required this.path,
  });

  final WorldId worldId;
  final String name;
  final String source;
  final String path;
}

final class RuntimeWorldImportFailure {
  const RuntimeWorldImportFailure({required this.path, required this.error});

  final String path;
  final Object error;
}

final class RuntimeWorldDirectoryImportResult {
  const RuntimeWorldDirectoryImportResult({
    required this.imported,
    required this.failures,
  });

  final List<RuntimeWorldLibraryEntry> imported;
  final List<RuntimeWorldImportFailure> failures;
}

/// Application-owned catalog for validated runtime-imported prototype worlds.
final class RuntimeWorldLibrary {
  RuntimeWorldLibrary({
    required this.directory,
    required this.assetAvailability,
    WorldPackageCodec? codec,
    this.maximumSourceBytes = 16 * 1024 * 1024,
  }) : _codec = codec ?? WorldPackageCodec();

  final Directory directory;
  final WorldAssetAvailability assetAvailability;
  final int maximumSourceBytes;
  final WorldPackageCodec _codec;
  Future<void> _queue = Future<void>.value();

  Future<RuntimeWorldLibraryEntry> importFile(String sourcePath) async {
    final file = File(sourcePath);
    try {
      final length = await file.length();
      if (length > maximumSourceBytes) {
        _tooLarge(length);
      }
      return importSource(await file.readAsString());
    } on AvarraException {
      rethrow;
    } on FileSystemException catch (error) {
      _storageFailure('importRead', sourcePath, error);
    }
  }

  /// Imports every top-level `.avarra` file from a creator/share directory.
  ///
  /// Individual invalid maps are reported without preventing valid siblings
  /// from reaching the application-owned catalog.
  Future<RuntimeWorldDirectoryImportResult> importDirectory(
    String sourcePath,
  ) async {
    final sourceDirectory = Directory(sourcePath);
    try {
      final files = await sourceDirectory
          .list(followLinks: false)
          .where((entry) => entry is File)
          .cast<File>()
          .where((file) => file.path.toLowerCase().endsWith('.avarra'))
          .toList();
      files.sort((left, right) => left.path.compareTo(right.path));

      final imported = <RuntimeWorldLibraryEntry>[];
      final failures = <RuntimeWorldImportFailure>[];
      for (final file in files) {
        try {
          imported.add(await importFile(file.path));
        } on Object catch (error) {
          failures.add(
            RuntimeWorldImportFailure(path: file.path, error: error),
          );
        }
      }
      return RuntimeWorldDirectoryImportResult(
        imported: List.unmodifiable(imported),
        failures: List.unmodifiable(failures),
      );
    } on FileSystemException catch (error) {
      _storageFailure('importDirectory', sourcePath, error);
    }
  }

  Future<RuntimeWorldLibraryEntry> importSource(String source) {
    return _serialized(() async {
      final sourceBytes = utf8.encode(source).length;
      if (sourceBytes > maximumSourceBytes) {
        _tooLarge(sourceBytes);
      }
      final definition = _codec.decode(source);
      const PlayableWorldValidator().validate(definition).throwIfInvalid();
      await _requireAssets(definition);
      final canonical = _codec.encodeCanonical(definition);
      await directory.create(recursive: true);
      final target = _worldFile(definition.id);
      await _writeAtomic(target, canonical);
      await _writeAtomic(_selectionFile, definition.id.value);
      return RuntimeWorldLibraryEntry(
        worldId: definition.id,
        name: definition.name,
        source: canonical,
        path: target.path,
      );
    });
  }

  Future<List<RuntimeWorldLibraryEntry>> list() {
    return _serialized(() async {
      try {
        await directory.create(recursive: true);
        final files =
            directory
                .listSync()
                .whereType<File>()
                .where((file) => file.path.toLowerCase().endsWith('.avarra'))
                .toList()
              ..sort((left, right) => left.path.compareTo(right.path));
        final entries = <RuntimeWorldLibraryEntry>[];
        for (final file in files) {
          try {
            final source = await _readRecovered(file);
            final definition = _codec.decode(source);
            entries.add(
              RuntimeWorldLibraryEntry(
                worldId: definition.id,
                name: definition.name,
                source: source,
                path: file.path,
              ),
            );
          } on AvarraException {
            // A malformed catalog entry must not block built-in recovery or
            // importing a replacement. Loading it directly still diagnoses it.
          }
        }
        return List.unmodifiable(entries);
      } on AvarraException {
        rethrow;
      } on FileSystemException catch (error) {
        _storageFailure('list', directory.path, error);
      }
    });
  }

  Future<RuntimeWorldLibraryEntry?> loadSelected() {
    return _serialized(() async {
      try {
        await directory.create(recursive: true);
        if (!await _selectionFile.exists()) {
          return null;
        }
        final value = (await _readRecovered(_selectionFile)).trim();
        final worldId = WorldId.tryParse(value);
        if (worldId == null) {
          _invalidSelection(value);
        }
        return _loadEntry(worldId);
      } on AvarraException {
        rethrow;
      } on FileSystemException catch (error) {
        _storageFailure('loadSelected', directory.path, error);
      }
    });
  }

  Future<RuntimeWorldLibraryEntry> select(WorldId worldId) {
    return _serialized(() async {
      try {
        final entry = await _loadEntry(worldId);
        await _writeAtomic(_selectionFile, worldId.value);
        return entry;
      } on AvarraException {
        rethrow;
      } on FileSystemException catch (error) {
        _storageFailure('select', worldId.value, error);
      }
    });
  }

  Future<void> clearSelection() {
    return _serialized(() async {
      try {
        for (final file in _relatedFiles(_selectionFile)) {
          if (await file.exists()) {
            await file.delete();
          }
        }
      } on FileSystemException catch (error) {
        _storageFailure('clearSelection', directory.path, error);
      }
    });
  }

  Future<RuntimeWorldLibraryEntry> _loadEntry(WorldId worldId) async {
    final target = _worldFile(worldId);
    if (!await target.exists() &&
        !await File('${target.path}.backup').exists()) {
      _invalidSelection(worldId.value);
    }
    final source = await _readRecovered(target);
    final definition = _codec.decode(source);
    const PlayableWorldValidator().validate(definition).throwIfInvalid();
    if (definition.id != worldId) {
      _invalidSelection(worldId.value);
    }
    await _requireAssets(definition);
    return RuntimeWorldLibraryEntry(
      worldId: definition.id,
      name: definition.name,
      source: _codec.encodeCanonical(definition),
      path: target.path,
    );
  }

  Future<void> _requireAssets(WorldDefinition definition) async {
    final missing = <String>[];
    for (final asset in definition.assets) {
      if (!await assetAvailability(asset.path)) {
        missing.add(asset.path);
      }
    }
    if (missing.isNotEmpty) {
      throw AvarraException(
        code: RuntimeWorldLibraryErrorCodes.assetUnavailable,
        message: 'The imported world requires assets unavailable in this Game.',
        context: {'worldId': definition.id.value, 'paths': missing..sort()},
      );
    }
  }

  Future<String> _readRecovered(File target) async {
    final files = _files(target);
    await _recover(files);
    return target.readAsString();
  }

  Future<void> _writeAtomic(File target, String source) async {
    final files = _files(target);
    await _recover(files);
    final handle = await files.temporary.open(mode: FileMode.write);
    try {
      await handle.writeString(source);
      await handle.flush();
    } finally {
      await handle.close();
    }
    if (await files.backup.exists()) {
      await files.backup.delete();
    }
    if (await target.exists()) {
      await target.rename(files.backup.path);
    }
    try {
      await files.temporary.rename(target.path);
    } on FileSystemException {
      if (!await target.exists() && await files.backup.exists()) {
        await files.backup.rename(target.path);
      }
      rethrow;
    }
    if (await files.backup.exists()) {
      await files.backup.delete();
    }
  }

  Future<void> _recover(_RuntimeWorldFiles files) async {
    if (!await files.target.exists() && await files.backup.exists()) {
      await files.backup.rename(files.target.path);
    }
    if (await files.target.exists() && await files.backup.exists()) {
      await files.backup.delete();
    }
    if (await files.temporary.exists()) {
      await files.temporary.delete();
    }
  }

  List<File> _relatedFiles(File target) {
    return [
      target,
      File('${target.path}.pending'),
      File('${target.path}.backup'),
    ];
  }

  _RuntimeWorldFiles _files(File target) {
    return _RuntimeWorldFiles(
      target: target,
      temporary: File('${target.path}.pending'),
      backup: File('${target.path}.backup'),
    );
  }

  File _worldFile(WorldId id) =>
      File('${directory.path}${Platform.pathSeparator}${id.value}.avarra');

  File get _selectionFile =>
      File('${directory.path}${Platform.pathSeparator}selected_world');

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Never _tooLarge(int bytes) {
    throw AvarraException(
      code: RuntimeWorldLibraryErrorCodes.sourceTooLarge,
      message: 'The imported world exceeds the prototype size limit.',
      context: {'bytes': bytes, 'maximumBytes': maximumSourceBytes},
    );
  }

  Never _invalidSelection(String value) {
    throw AvarraException(
      code: RuntimeWorldLibraryErrorCodes.selectionInvalid,
      message: 'The selected imported world is unavailable or inconsistent.',
      context: {'selection': value},
    );
  }

  Never _storageFailure(
    String operation,
    String path,
    FileSystemException error,
  ) {
    throw AvarraException(
      code: RuntimeWorldLibraryErrorCodes.storageFailure,
      message: 'The runtime world library storage operation failed.',
      context: {
        'operation': operation,
        'path': path,
        'osError': error.osError?.errorCode,
      },
    );
  }
}

final class _RuntimeWorldFiles {
  const _RuntimeWorldFiles({
    required this.target,
    required this.temporary,
    required this.backup,
  });

  final File target;
  final File temporary;
  final File backup;
}
