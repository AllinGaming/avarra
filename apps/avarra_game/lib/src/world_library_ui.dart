import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'runtime_world_library.dart';

enum RuntimeSessionMode { solo, host, join }

final class RuntimeSessionConfiguration {
  const RuntimeSessionConfiguration({
    this.mode = RuntimeSessionMode.solo,
    this.hostAddress = '127.0.0.1',
    this.port = 45454,
  }) : assert(port > 0 && port <= 65535);

  final RuntimeSessionMode mode;
  final String hostAddress;
  final int port;
}

final class RuntimeWorldSelection {
  const RuntimeWorldSelection({
    required this.source,
    required this.label,
    required this.isImported,
    this.session = const RuntimeSessionConfiguration(),
  });

  final String source;
  final String label;
  final bool isImported;
  final RuntimeSessionConfiguration session;

  RuntimeWorldSelection copyWith({RuntimeSessionConfiguration? session}) {
    return RuntimeWorldSelection(
      source: source,
      label: label,
      isImported: isImported,
      session: session ?? this.session,
    );
  }
}

typedef RuntimeWorldSelectionLoader = Future<RuntimeWorldSelection> Function();
typedef RuntimeWorldLibraryOpener =
    Future<RuntimeWorldSelection?> Function(BuildContext context);

const _worldTypes = <XTypeGroup>[
  XTypeGroup(label: 'Avarra world', extensions: ['avarra']),
];

Future<RuntimeWorldLibrary> createDefaultRuntimeWorldLibrary() async {
  final support = await getApplicationSupportDirectory();
  return RuntimeWorldLibrary(
    directory: Directory('${support.path}${Platform.pathSeparator}worlds'),
    assetAvailability: (path) async {
      try {
        await rootBundle.load(path);
        return true;
      } on Object {
        return false;
      }
    },
  );
}

Future<RuntimeWorldSelection> loadDefaultRuntimeWorldSelection({
  required String configuredFilePath,
  required String bundledAssetPath,
}) async {
  if (configuredFilePath.isNotEmpty) {
    return RuntimeWorldSelection(
      source: await File(configuredFilePath).readAsString(),
      label: configuredFilePath,
      isImported: true,
    );
  }
  final selected = await (await createDefaultRuntimeWorldLibrary())
      .loadSelected();
  if (selected != null) {
    return RuntimeWorldSelection(
      source: selected.source,
      label: selected.name,
      isImported: true,
    );
  }
  return RuntimeWorldSelection(
    source: await rootBundle.loadString(bundledAssetPath),
    label: 'Built-in Relay Zero Prototype',
    isImported: false,
  );
}

Future<RuntimeWorldSelection?> openDefaultRuntimeWorldLibrary(
  BuildContext context, {
  required String bundledAssetPath,
  RuntimeSessionConfiguration initialSession =
      const RuntimeSessionConfiguration(),
  RuntimeWorldLibrary? runtimeLibrary,
}) async {
  final library = runtimeLibrary ?? await createDefaultRuntimeWorldLibrary();
  var selectedKey = _bundledWorldKey;
  try {
    final selected = await library.loadSelected();
    if (selected != null) {
      selectedKey = selected.worldId.value;
    }
  } on AvarraException {
    await library.clearSelection();
  }
  var session = initialSession;

  while (context.mounted) {
    final entries = await library.list();
    if (selectedKey != _bundledWorldKey &&
        !entries.any((entry) => entry.worldId.value == selectedKey)) {
      selectedKey = _bundledWorldKey;
    }
    if (!context.mounted) return null;

    final choice = await _showWorldLibraryDialog(
      context,
      library: library,
      entries: entries,
      selectedKey: selectedKey,
      initialSession: session,
    );
    if (choice == null || !context.mounted) return null;
    selectedKey = choice.selectedKey;
    session = choice.session;

    switch (choice.action) {
      case _WorldLibraryAction.refresh:
        continue;
      case _WorldLibraryAction.importFile:
        final file = await openFile(acceptedTypeGroups: _worldTypes);
        if (file != null) {
          final imported = await library.importFile(file.path);
          selectedKey = imported.worldId.value;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Imported ${imported.name}')),
            );
          }
        }
        continue;
      case _WorldLibraryAction.importDirectory:
        final path = await getDirectoryPath(confirmButtonText: 'Import maps');
        if (path != null) {
          final result = await library.importDirectory(path);
          if (result.imported.isNotEmpty) {
            selectedKey = result.imported.last.worldId.value;
          }
          if (context.mounted) {
            await _showDirectoryImportResult(context, result);
          }
        }
        continue;
      case _WorldLibraryAction.launch:
        if (selectedKey == _bundledWorldKey) {
          await library.clearSelection();
          return RuntimeWorldSelection(
            source: await rootBundle.loadString(bundledAssetPath),
            label: 'Built-in Relay Zero: Ashfall',
            isImported: false,
            session: session,
          );
        }
        final entry = entries
            .where((candidate) => candidate.worldId.value == selectedKey)
            .firstOrNull;
        if (entry == null) continue;
        // Re-importing the chosen path canonicalizes maps dropped directly
        // into the visible library folder before persisting the selection.
        final selected = await library.importFile(entry.path);
        return RuntimeWorldSelection(
          source: selected.source,
          label: selected.name,
          isImported: true,
          session: session,
        );
    }
  }
  return null;
}

const _bundledWorldKey = 'bundled';

enum _WorldLibraryAction { launch, importFile, importDirectory, refresh }

final class _WorldLibraryChoice {
  const _WorldLibraryChoice({
    required this.action,
    required this.selectedKey,
    required this.session,
  });

  final _WorldLibraryAction action;
  final String selectedKey;
  final RuntimeSessionConfiguration session;
}

Future<_WorldLibraryChoice?> _showWorldLibraryDialog(
  BuildContext context, {
  required RuntimeWorldLibrary library,
  required List<RuntimeWorldLibraryEntry> entries,
  required String selectedKey,
  required RuntimeSessionConfiguration initialSession,
}) async {
  final hostController = TextEditingController(
    text: initialSession.hostAddress,
  );
  final portController = TextEditingController(text: '${initialSession.port}');
  try {
    return await showDialog<_WorldLibraryChoice>(
      context: context,
      builder: (dialogContext) {
        var currentKey = selectedKey;
        var currentMode = initialSession.mode;
        String? inputError;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            RuntimeSessionConfiguration session() {
              return RuntimeSessionConfiguration(
                mode: currentMode,
                hostAddress: hostController.text.trim(),
                port: int.parse(portController.text),
              );
            }

            void returnAction(_WorldLibraryAction action) {
              final port = int.tryParse(portController.text);
              final missingHost =
                  currentMode == RuntimeSessionMode.join &&
                  hostController.text.trim().isEmpty;
              if (port == null || port < 1 || port > 65535 || missingHost) {
                setDialogState(() {
                  inputError = missingHost
                      ? 'Enter the host address to join.'
                      : 'Port must be from 1 to 65535.';
                });
                return;
              }
              Navigator.pop(
                dialogContext,
                _WorldLibraryChoice(
                  action: action,
                  selectedKey: currentKey,
                  session: session(),
                ),
              );
            }

            return AlertDialog(
              title: const Text('Worlds & multiplayer'),
              content: SizedBox(
                width: 600,
                height: MediaQuery.sizeOf(context).height * 0.68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choose a map, then play solo, host it, or join a host '
                      'running the exact same map.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Maps folder: ${library.directory.path}',
                      key: const Key('runtime_maps_folder'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('import_world_file'),
                          onPressed: () =>
                              returnAction(_WorldLibraryAction.importFile),
                          icon: const Icon(Icons.note_add_outlined),
                          label: const Text('Import map'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('import_world_folder'),
                          onPressed: () =>
                              returnAction(_WorldLibraryAction.importDirectory),
                          icon: const Icon(Icons.create_new_folder_outlined),
                          label: const Text('Import folder'),
                        ),
                        IconButton.outlined(
                          key: const Key('refresh_world_library'),
                          tooltip: 'Refresh maps folder',
                          onPressed: () =>
                              returnAction(_WorldLibraryAction.refresh),
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: RadioGroup<String>(
                        groupValue: currentKey,
                        onChanged: (value) => setDialogState(
                          () => currentKey = value ?? currentKey,
                        ),
                        child: ListView(
                          children: [
                            RadioListTile<String>(
                              key: const Key('select_bundled_world'),
                              value: _bundledWorldKey,
                              secondary: const Icon(
                                Icons.auto_awesome_outlined,
                              ),
                              title: const Text('Relay Zero: Ashfall'),
                              subtitle: const Text(
                                'Built into this Game release',
                              ),
                            ),
                            for (final entry in entries)
                              RadioListTile<String>(
                                key: Key('select_world_${entry.worldId.value}'),
                                value: entry.worldId.value,
                                secondary: const Icon(Icons.public),
                                title: Text(entry.name),
                                subtitle: Text(entry.worldId.value),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final mode in RuntimeSessionMode.values)
                          ChoiceChip(
                            key: Key('session_mode_${mode.name}'),
                            selected: currentMode == mode,
                            onSelected: (_) =>
                                setDialogState(() => currentMode = mode),
                            avatar: Icon(_sessionIcon(mode), size: 18),
                            label: Text(_sessionLabel(mode)),
                          ),
                      ],
                    ),
                    if (currentMode != RuntimeSessionMode.solo) ...[
                      const SizedBox(height: 8),
                      if (currentMode == RuntimeSessionMode.join)
                        TextField(
                          key: const Key('join_host_address'),
                          controller: hostController,
                          decoration: const InputDecoration(
                            labelText: 'Host address',
                            hintText: '192.168.1.42',
                          ),
                        ),
                      TextField(
                        key: const Key('multiplayer_port'),
                        controller: portController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Port'),
                      ),
                    ],
                    if (inputError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          inputError!,
                          key: const Key('session_input_error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  key: const Key('launch_world_session'),
                  onPressed: () => returnAction(_WorldLibraryAction.launch),
                  icon: Icon(_sessionIcon(currentMode)),
                  label: Text(_sessionLaunchLabel(currentMode)),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    hostController.dispose();
    portController.dispose();
  }
}

Future<void> _showDirectoryImportResult(
  BuildContext context,
  RuntimeWorldDirectoryImportResult result,
) {
  final failures = result.failures.take(5).toList();
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Map folder import'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${result.imported.length} map(s) imported.'),
            if (result.failures.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${result.failures.length} map(s) rejected:'),
              for (final failure in failures)
                Text(
                  '• ${File(failure.path).uri.pathSegments.last}: '
                  '${failure.error}',
                ),
              if (result.failures.length > failures.length)
                Text('…and ${result.failures.length - failures.length} more.'),
            ],
            if (result.imported.isEmpty && result.failures.isEmpty)
              const Text('No top-level .avarra files were found.'),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}

String _sessionLabel(RuntimeSessionMode mode) => switch (mode) {
  RuntimeSessionMode.solo => 'Solo',
  RuntimeSessionMode.host => 'Host',
  RuntimeSessionMode.join => 'Join',
};

String _sessionLaunchLabel(RuntimeSessionMode mode) => switch (mode) {
  RuntimeSessionMode.solo => 'Play solo',
  RuntimeSessionMode.host => 'Host map',
  RuntimeSessionMode.join => 'Join game',
};

IconData _sessionIcon(RuntimeSessionMode mode) => switch (mode) {
  RuntimeSessionMode.solo => Icons.sports_esports,
  RuntimeSessionMode.host => Icons.cell_tower,
  RuntimeSessionMode.join => Icons.lan,
};
