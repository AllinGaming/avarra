import 'dart:convert';
import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_creator_api/avarra_creator_api.dart';
import 'package:file_selector/file_selector.dart';

enum ForgeSaveKind { project, worldExport }

abstract interface class ForgeFileDialogs {
  Future<String?> openProjectPath();
  Future<String?> chooseSavePath({
    required ForgeSaveKind kind,
    required String suggestedName,
  });
}

final class PlatformForgeFileDialogs implements ForgeFileDialogs {
  const PlatformForgeFileDialogs();

  static const _projectTypes = <XTypeGroup>[
    XTypeGroup(label: 'Avarra Forge project', extensions: ['avarra-forge']),
  ];
  static const _worldTypes = <XTypeGroup>[
    XTypeGroup(label: 'Avarra world', extensions: ['avarra']),
  ];

  @override
  Future<String?> openProjectPath() async {
    final file = await openFile(acceptedTypeGroups: _projectTypes);
    return file?.path;
  }

  @override
  Future<String?> chooseSavePath({
    required ForgeSaveKind kind,
    required String suggestedName,
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: switch (kind) {
        ForgeSaveKind.project => _projectTypes,
        ForgeSaveKind.worldExport => _worldTypes,
      },
    );
    return location?.path;
  }
}

final class ForgeProjectFileRead {
  const ForgeProjectFileRead({
    required this.source,
    required this.recoverySource,
    required this.recoveryIsApplicable,
  });

  final String source;
  final String? recoverySource;
  final bool recoveryIsApplicable;
}

abstract interface class ForgeProjectStorage {
  Future<bool> exists(String path);
  Future<ForgeProjectFileRead> readProject(String path);
  Future<void> writeAtomic(
    String path,
    String source, {
    required bool overwrite,
  });
  Future<void> writeRecovery(String projectPath, String source);
  Future<void> clearRecovery(String projectPath);
}

/// Recoverable same-directory storage for Forge source and prototype exports.
final class ForgeProjectFileStorage implements ForgeProjectStorage {
  ForgeProjectFileStorage();

  Future<void> _queue = Future<void>.value();

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<ForgeProjectFileRead> readProject(String path) {
    return _serialized(() async {
      final target = File(path);
      final files = _files(target);
      try {
        await _recover(files);
        if (!await target.exists()) {
          _storageFailure('read', path, null);
        }
        final source = await target.readAsString();
        final recovery = File('$path.recovery');
        await _recover(_files(recovery));
        final recoveryExists = await recovery.exists();
        String? recoverySource;
        var recoveryIsApplicable = false;
        if (recoveryExists) {
          try {
            final decoded = jsonDecode(await recovery.readAsString());
            if (decoded is Map<String, dynamic> &&
                decoded.length == 4 &&
                decoded['format'] == 'avarra.forge_recovery' &&
                decoded['recoveryFormatVersion'] == 1 &&
                decoded['baseSource'] is String &&
                decoded['recoverySource'] is String) {
              recoverySource = decoded['recoverySource'] as String;
              recoveryIsApplicable = decoded['baseSource'] == source;
            }
          } on FormatException {
            // A partial/corrupt optional recovery never replaces saved source.
          }
        }
        return ForgeProjectFileRead(
          source: source,
          recoverySource: recoverySource,
          recoveryIsApplicable: recoveryIsApplicable,
        );
      } on FileSystemException catch (error) {
        _storageFailure('read', path, error);
      }
    });
  }

  @override
  Future<void> writeAtomic(
    String path,
    String source, {
    required bool overwrite,
  }) {
    return _serialized(() async {
      final target = File(path);
      try {
        if (await target.exists() && !overwrite) {
          throw AvarraException(
            code: CreatorErrorCodes.fileExists,
            message: 'The selected file already exists.',
            context: {'path': path},
          );
        }
        await target.parent.create(recursive: true);
        await _writeAtomic(target, source);
      } on AvarraException {
        rethrow;
      } on FileSystemException catch (error) {
        _storageFailure('write', path, error);
      }
    });
  }

  @override
  Future<void> writeRecovery(String projectPath, String source) {
    return _serialized(() async {
      final target = File('$projectPath.recovery');
      try {
        await target.parent.create(recursive: true);
        final project = File(projectPath);
        await _recover(_files(project));
        if (!await project.exists()) {
          _storageFailure('writeRecovery', projectPath, null);
        }
        await _writeAtomic(
          target,
          jsonEncode({
            'format': 'avarra.forge_recovery',
            'recoveryFormatVersion': 1,
            'baseSource': await project.readAsString(),
            'recoverySource': source,
          }),
        );
      } on FileSystemException catch (error) {
        _storageFailure('writeRecovery', projectPath, error);
      }
    });
  }

  @override
  Future<void> clearRecovery(String projectPath) {
    return _serialized(() async {
      try {
        for (final target in [
          File('$projectPath.recovery'),
          File('$projectPath.recovery.base'),
        ]) {
          final files = _files(target);
          for (final file in [files.temporary, files.backup, files.target]) {
            if (await file.exists()) {
              await file.delete();
            }
          }
        }
      } on FileSystemException catch (error) {
        _storageFailure('clearRecovery', projectPath, error);
      }
    });
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<void> _writeAtomic(File target, String source) async {
    final files = _files(target);
    await _recover(files);
    if (await files.temporary.exists()) {
      await files.temporary.delete();
    }
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

  Future<void> _recover(_ForgeFiles files) async {
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

  _ForgeFiles _files(File target) {
    return _ForgeFiles(
      target: target,
      temporary: File('${target.path}.pending'),
      backup: File('${target.path}.backup'),
    );
  }

  Never _storageFailure(
    String operation,
    String path,
    FileSystemException? error,
  ) {
    throw AvarraException(
      code: CreatorErrorCodes.projectStorageFailure,
      message: 'Forge project storage operation failed.',
      context: {
        'operation': operation,
        'path': path,
        if (error != null) 'osError': error.osError?.errorCode,
      },
    );
  }
}

final class _ForgeFiles {
  const _ForgeFiles({
    required this.target,
    required this.temporary,
    required this.backup,
  });

  final File target;
  final File temporary;
  final File backup;
}

String ensureForgeFileExtension(String path, ForgeSaveKind kind) {
  final extension = switch (kind) {
    ForgeSaveKind.project => avarraForgeProjectExtension,
    ForgeSaveKind.worldExport => '.avarra',
  };
  return path.toLowerCase().endsWith(extension) ? path : '$path$extension';
}
