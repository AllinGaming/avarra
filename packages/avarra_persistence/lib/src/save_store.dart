import 'dart:async';
import 'dart:io';

import 'package:avarra_core/avarra_core.dart';

import 'persistence_error_codes.dart';

abstract interface class SaveStore {
  Future<String?> read(SaveId saveId);
  Future<void> writeAtomic(SaveId saveId, String contents);
}

final class MemorySaveStore implements SaveStore {
  final Map<SaveId, String> _values = {};

  @override
  Future<String?> read(SaveId saveId) async => _values[saveId];

  @override
  Future<void> writeAtomic(SaveId saveId, String contents) async {
    _values[saveId] = contents;
  }
}

/// Recoverable same-directory file replacement for Windows/Android/server.
final class FileSaveStore implements SaveStore {
  FileSaveStore(this.directory);

  final Directory directory;
  Future<void> _queue = Future<void>.value();

  @override
  Future<String?> read(SaveId saveId) {
    return _serialized(() async {
      try {
        await directory.create(recursive: true);
        final files = _files(saveId);
        await _recover(files);
        if (!await files.target.exists()) {
          return null;
        }
        return files.target.readAsString();
      } on FileSystemException catch (error) {
        _storageFailure('read', saveId, error);
      }
    });
  }

  @override
  Future<void> writeAtomic(SaveId saveId, String contents) {
    return _serialized(() async {
      final files = _files(saveId);
      try {
        await directory.create(recursive: true);
        await _recover(files);
        if (await files.temporary.exists()) {
          await files.temporary.delete();
        }

        final handle = await files.temporary.open(mode: FileMode.write);
        try {
          await handle.writeString(contents);
          await handle.flush();
        } finally {
          await handle.close();
        }

        if (await files.backup.exists()) {
          await files.backup.delete();
        }
        if (await files.target.exists()) {
          await files.target.rename(files.backup.path);
        }
        try {
          await files.temporary.rename(files.target.path);
        } on FileSystemException {
          if (!await files.target.exists() && await files.backup.exists()) {
            await files.backup.rename(files.target.path);
          }
          rethrow;
        }
        if (await files.backup.exists()) {
          await files.backup.delete();
        }
      } on FileSystemException catch (error) {
        _storageFailure('write', saveId, error);
      }
    });
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  _SaveFiles _files(SaveId saveId) {
    final base = '${saveId.value}.avsave';
    return _SaveFiles(
      target: File('${directory.path}${Platform.pathSeparator}$base'),
      temporary: File(
        '${directory.path}${Platform.pathSeparator}$base.pending',
      ),
      backup: File('${directory.path}${Platform.pathSeparator}$base.backup'),
    );
  }

  Future<void> _recover(_SaveFiles files) async {
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

  Never _storageFailure(
    String operation,
    SaveId saveId,
    FileSystemException error,
  ) {
    throw AvarraException(
      code: PersistenceErrorCodes.storageFailure,
      message: 'Atomic save storage operation failed.',
      context: {
        'operation': operation,
        'saveId': saveId.value,
        'osError': error.osError?.errorCode,
      },
    );
  }
}

final class _SaveFiles {
  const _SaveFiles({
    required this.target,
    required this.temporary,
    required this.backup,
  });

  final File target;
  final File temporary;
  final File backup;
}
