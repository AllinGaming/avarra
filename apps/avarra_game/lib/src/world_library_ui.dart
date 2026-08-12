import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'runtime_world_library.dart';

final class RuntimeWorldSelection {
  const RuntimeWorldSelection({
    required this.source,
    required this.label,
    required this.isImported,
  });

  final String source;
  final String label;
  final bool isImported;
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
}) async {
  final library = await createDefaultRuntimeWorldLibrary();
  final entries = await library.list();
  if (!context.mounted) {
    return null;
  }
  final choice = await showDialog<_WorldLibraryChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('World library'),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              key: const Key('select_bundled_world'),
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Relay Zero Prototype'),
              subtitle: const Text('Built into this Game release'),
              onTap: () =>
                  Navigator.pop(context, const _WorldLibraryChoice.bundled()),
            ),
            for (final entry in entries)
              ListTile(
                key: Key('select_world_${entry.worldId.value}'),
                leading: const Icon(Icons.public),
                title: Text(entry.name),
                subtitle: Text(entry.worldId.value),
                onTap: () =>
                    Navigator.pop(context, _WorldLibraryChoice.imported(entry)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('import_world_file'),
          onPressed: () =>
              Navigator.pop(context, const _WorldLibraryChoice.importFile()),
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('Import'),
        ),
      ],
    ),
  );
  if (choice == null) {
    return null;
  }
  if (choice.useBundled) {
    await library.clearSelection();
    return RuntimeWorldSelection(
      source: await rootBundle.loadString(bundledAssetPath),
      label: 'Built-in Relay Zero Prototype',
      isImported: false,
    );
  }
  final chosenEntry = choice.entry;
  if (chosenEntry != null) {
    final selected = await library.select(chosenEntry.worldId);
    return RuntimeWorldSelection(
      source: selected.source,
      label: selected.name,
      isImported: true,
    );
  }
  final file = await openFile(acceptedTypeGroups: _worldTypes);
  if (file == null) {
    return null;
  }
  final imported = await library.importFile(file.path);
  return RuntimeWorldSelection(
    source: imported.source,
    label: imported.name,
    isImported: true,
  );
}

final class _WorldLibraryChoice {
  const _WorldLibraryChoice.bundled() : useBundled = true, entry = null;

  const _WorldLibraryChoice.importFile() : useBundled = false, entry = null;

  const _WorldLibraryChoice.imported(this.entry) : useBundled = false;

  final bool useBundled;
  final RuntimeWorldLibraryEntry? entry;
}
