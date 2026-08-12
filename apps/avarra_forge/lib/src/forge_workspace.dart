import 'dart:async';

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_creator_api/avarra_creator_api.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';

import 'forge_file_services.dart';
import 'forge_panels.dart';
import 'forge_sample_world.dart';
import 'forge_viewport.dart';

final class ForgeWorkspaceScreen extends StatefulWidget {
  const ForgeWorkspaceScreen({
    required this.initialWorld,
    required this.projectStorage,
    required this.fileDialogs,
    required this.enableRenderer,
    super.key,
  });

  final WorldDefinition initialWorld;
  final ForgeProjectStorage projectStorage;
  final ForgeFileDialogs fileDialogs;
  final bool enableRenderer;

  @override
  State<ForgeWorkspaceScreen> createState() => _ForgeWorkspaceScreenState();
}

final class _ForgeWorkspaceScreenState extends State<ForgeWorkspaceScreen> {
  final ForgeProjectCodec _projectCodec = ForgeProjectCodec();
  final WorldPackageCodec _worldCodec = WorldPackageCodec();
  final ComponentSchemaRegistry _schemas = ComponentSchemaRegistry.builtIn();
  late CreatorWorldSession _session;
  late CreatorValidationReport _validation;
  EntityId? _selectedEntityId;
  String? _projectPath;
  String _status = 'Ready · canonical world is valid';
  bool _busy = false;
  bool _allowPop = false;
  Timer? _recoveryTimer;

  WorldDefinition get _world => _session.world;

  WorldEntityDefinition? get _selectedEntity {
    final selectedId = _selectedEntityId;
    if (selectedId == null) return null;
    return _world.allEntities
        .where((entity) => entity.id == selectedId)
        .firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    _session = CreatorWorldSession(initialWorld: widget.initialWorld);
    _selectedEntityId = _world.allEntities.firstOrNull?.id;
    _validation = _session.validate(requirePlayableEntry: true);
  }

  @override
  void dispose() {
    _recoveryTimer?.cancel();
    super.dispose();
  }

  void _refreshValidation() {
    _validation = _session.validate(requirePlayableEntry: true);
  }

  void _execute(CreatorCommand command, {EntityId? select}) {
    try {
      _session.execute(command);
      setState(() {
        _selectedEntityId = select ?? _selectedEntityId;
        _refreshValidation();
        _status = '${command.description} · revision ${_session.revision}';
      });
      _scheduleRecovery();
    } on AvarraException catch (error) {
      setState(() => _status = '${error.code.value}: ${error.message}');
    }
  }

  void _addCube() {
    final id = EntityId.generate();
    final index = _world.allEntities.length;
    _execute(
      CreateEntityCommand(
        entity: WorldEntityDefinition(
          id: id,
          components: [
            TransformDefinition(
              position: ContentVector3(
                1.25 * ((index - 2) % 4),
                0.5,
                1.25 * ((index - 2) ~/ 4),
              ),
              rotation: const ContentQuaternion(0, 0, 0, 1),
              scale: const ContentVector3(1, 1, 1),
            ),
            RenderableReferenceDefinition(assetId: forgeSampleAssetId),
          ],
        ),
      ),
      select: id,
    );
  }

  void _deleteSelected() {
    final selectedId = _selectedEntityId;
    if (selectedId == null) return;
    _execute(DeleteEntityCommand(selectedId));
    setState(() => _selectedEntityId = _world.allEntities.firstOrNull?.id);
  }

  void _setField(String componentType, String fieldName, Object? value) {
    final selectedId = _selectedEntityId;
    if (selectedId == null) return;
    _execute(
      SetEntityComponentFieldCommand(
        entityId: selectedId,
        componentType: componentType,
        fieldName: fieldName,
        value: value,
      ),
    );
  }

  void _addComponent(String type) {
    final entity = _selectedEntity;
    if (entity == null) return;
    final knownTypes = entity.components.keys.toSet();
    final commands = <CreatorCommand>[];

    void addWithDependencies(String nextType) {
      if (!knownTypes.add(nextType)) return;
      final schema = _schemas.schemaFor(nextType);
      if (schema == null) return;
      for (final dependency in schema.requiredComponentTypes) {
        addWithDependencies(dependency);
      }
      final contextualFields =
          nextType == AvarraComponentType.renderableReference &&
              _world.assets.isNotEmpty
          ? <String, Object?>{'assetId': _world.assets.first.id.value}
          : const <String, Object?>{};
      commands.add(
        AddEntityComponentCommand(
          entityId: entity.id,
          component: _schemas.createDefault(
            nextType,
            fieldValues: contextualFields,
          ),
        ),
      );
      for (final constraint in schema.dependencyFieldValues.entries) {
        for (final field in constraint.value.entries) {
          commands.add(
            SetEntityComponentFieldCommand(
              entityId: entity.id,
              componentType: constraint.key,
              fieldName: field.key,
              value: field.value,
            ),
          );
        }
      }
    }

    try {
      addWithDependencies(type);
      _execute(
        CreatorCommandBatch(
          description: 'Add ${_schemas.schemaFor(type)?.label ?? type}',
          commands: commands,
        ),
      );
    } on AvarraException catch (error) {
      setState(() => _status = '${error.code.value}: ${error.message}');
    }
  }

  void _removeComponent(String type) {
    final selectedId = _selectedEntityId;
    if (selectedId == null) return;
    _execute(
      RemoveEntityComponentCommand(entityId: selectedId, componentType: type),
    );
  }

  void _commitViewportTransform(PresentationTransform transform) {
    final selectedId = _selectedEntityId;
    final selected = _selectedEntity;
    if (selectedId == null || selected == null) return;
    var x = transform.position.x;
    var z = transform.position.z;
    final chunkSize = _world.chunkSize ?? 0;
    for (final chunk in _world.chunks) {
      if (chunk.entities.any((entity) => entity.id == selectedId)) {
        x -= chunk.coordinate.x * chunkSize;
        z -= chunk.coordinate.z * chunkSize;
        break;
      }
    }
    _execute(
      SetEntityTransformCommand(
        entityId: selectedId,
        transform: TransformDefinition(
          position: ContentVector3(x, transform.position.y, z),
          rotation: ContentQuaternion(
            transform.rotation.x,
            transform.rotation.y,
            transform.rotation.z,
            transform.rotation.w,
          ),
          scale: ContentVector3(
            transform.scale.x,
            transform.scale.y,
            transform.scale.z,
          ),
        ),
      ),
    );
  }

  void _undo() {
    if (!_session.undo()) return;
    setState(() {
      if (_selectedEntity == null) {
        _selectedEntityId = _world.allEntities.firstOrNull?.id;
      }
      _refreshValidation();
      _status = 'Undo · revision ${_session.revision}';
    });
    _scheduleRecovery();
  }

  void _redo() {
    if (!_session.redo()) return;
    setState(() {
      _refreshValidation();
      _status = 'Redo · revision ${_session.revision}';
    });
    _scheduleRecovery();
  }

  void _validate() {
    setState(() {
      _refreshValidation();
      _status = _validation.isValid
          ? 'Validation passed · ready for Game import'
          : '${_validation.issues.length} validation issue(s)';
    });
  }

  void _replaceProject(
    WorldDefinition world, {
    required String? path,
    WorldDefinition? savedWorld,
  }) {
    _recoveryTimer?.cancel();
    _session = CreatorWorldSession(initialWorld: world);
    if (savedWorld != null) {
      _session.markSaved(
        exportedSource: _worldCodec.encodeCanonical(savedWorld),
      );
    }
    _projectPath = path;
    _selectedEntityId = world.allEntities.firstOrNull?.id;
    _refreshValidation();
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_session.isDirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard unsaved changes?'),
            content: const Text(
              'The editable Forge project has changes that have not been saved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                key: const Key('confirm_discard'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmOverwrite(String path) async {
    if (!await widget.projectStorage.exists(path) || !mounted) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Replace existing file?'),
            content: Text(path),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('confirm_overwrite'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _newProject() async {
    if (!await _confirmDiscardChanges() || !mounted) return;
    setState(() {
      _replaceProject(createForgeStarterWorld(), path: null);
      _status = 'New unsaved Relay Zero starter project';
    });
  }

  Future<void> _openProject() async {
    if (!await _confirmDiscardChanges()) return;
    final path = await widget.fileDialogs.openProjectPath();
    if (path == null || !mounted) return;
    setState(() {
      _busy = true;
      _status = 'Opening project…';
    });
    try {
      final loaded = await widget.projectStorage.readProject(path);
      final primary = _projectCodec.decode(loaded.source);
      var selected = primary;
      var recovered = false;
      final recoverySource = loaded.recoverySource;
      if (recoverySource != null &&
          loaded.recoveryIsApplicable &&
          recoverySource != loaded.source &&
          mounted) {
        final useRecovery =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Recover unsaved project changes?'),
                content: const Text(
                  'Forge found a newer recovery snapshot beside this project.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Use saved project'),
                  ),
                  FilledButton(
                    key: const Key('confirm_recovery'),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Recover'),
                  ),
                ],
              ),
            ) ??
            false;
        if (useRecovery) {
          selected = _projectCodec.decode(recoverySource);
          recovered = true;
        } else {
          await widget.projectStorage.clearRecovery(path);
        }
      }
      if (mounted) {
        setState(() {
          _replaceProject(
            selected.world,
            path: path,
            savedWorld: recovered ? primary.world : null,
          );
          _status = recovered
              ? 'Recovered unsaved changes from $path'
              : 'Opened $path';
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _status = 'Open failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveProject({bool saveAs = false}) async {
    var path = saveAs ? null : _projectPath;
    if (path == null) {
      path = await widget.fileDialogs.chooseSavePath(
        kind: ForgeSaveKind.project,
        suggestedName: '${_safeFileName(_world.name)}.avarra-forge',
      );
      if (path == null || !mounted) return;
      path = ensureForgeFileExtension(path, ForgeSaveKind.project);
      if (!await _confirmOverwrite(path)) return;
    }
    setState(() {
      _busy = true;
      _status = 'Saving project…';
    });
    try {
      final source = _projectCodec.encodeCanonical(ForgeProject(world: _world));
      await widget.projectStorage.writeAtomic(path, source, overwrite: true);
      await widget.projectStorage.clearRecovery(path);
      _session.markSaved();
      if (mounted) {
        setState(() {
          _projectPath = path;
          _status = 'Saved project to $path';
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _status = 'Save failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _scheduleRecovery() {
    final path = _projectPath;
    if (path == null || !_session.isDirty) return;
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final source = _projectCodec.encodeCanonical(
          ForgeProject(world: _world),
        );
        await widget.projectStorage.writeRecovery(path, source);
        if (mounted) {
          setState(() => _status = 'Recovery snapshot updated');
        }
      } on Object catch (error) {
        if (mounted) {
          setState(() => _status = 'Recovery snapshot failed: $error');
        }
      }
    });
  }

  Future<void> _export() async {
    var path = await widget.fileDialogs.chooseSavePath(
      kind: ForgeSaveKind.worldExport,
      suggestedName: '${_safeFileName(_world.name)}.avarra',
    );
    if (path == null || !mounted) return;
    path = ensureForgeFileExtension(path, ForgeSaveKind.worldExport);
    if (!await _confirmOverwrite(path) || !mounted) return;
    setState(() {
      _busy = true;
      _status = 'Exporting…';
    });
    try {
      final source = _session.exportCanonical();
      await widget.projectStorage.writeAtomic(path, source, overwrite: true);
      if (mounted) {
        setState(() => _status = 'Exported ${source.length} bytes to $path');
      }
    } on Object catch (error) {
      if (mounted) setState(() => _status = 'Export failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handlePop(bool didPop) async {
    if (didPop || _allowPop || !mounted) return;
    if (await _confirmDiscardChanges() && mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dirtyMarker = _session.isDirty ? ' •' : '';
    final location = _projectPath == null ? 'Unsaved project' : _projectPath!;
    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text('Avarra Forge — ${_world.name}$dirtyMarker'),
        actions: [
          IconButton(
            key: const Key('new_project'),
            tooltip: 'New project',
            onPressed: _busy ? null : _newProject,
            icon: const Icon(Icons.note_add_outlined),
          ),
          IconButton(
            key: const Key('open_project'),
            tooltip: 'Open project',
            onPressed: _busy ? null : _openProject,
            icon: const Icon(Icons.folder_open_outlined),
          ),
          IconButton(
            key: const Key('save_project'),
            tooltip: 'Save project',
            onPressed: _busy ? null : _saveProject,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            key: const Key('save_project_as'),
            tooltip: 'Save project as',
            onPressed: _busy ? null : () => _saveProject(saveAs: true),
            icon: const Icon(Icons.save_as_outlined),
          ),
          IconButton(
            key: const Key('undo'),
            tooltip: 'Undo',
            onPressed: _session.canUndo && !_busy ? _undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            key: const Key('redo'),
            tooltip: 'Redo',
            onPressed: _session.canRedo && !_busy ? _redo : null,
            icon: const Icon(Icons.redo),
          ),
          TextButton.icon(
            key: const Key('validate'),
            onPressed: _busy ? null : _validate,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Validate'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const Key('export'),
            onPressed: _busy || _validation.blocksExport ? null : _export,
            icon: const Icon(Icons.ios_share),
            label: const Text('Export'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 240,
                  child: HierarchyPanel(
                    world: _world,
                    selectedEntityId: _selectedEntityId,
                    onSelected: (id) => setState(() => _selectedEntityId = id),
                    onAdd: _addCube,
                    onDelete: _deleteSelected,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: ForgeViewport(
                    world: _world,
                    selectedEntityId: _selectedEntityId,
                    onSelected: (id) => setState(() => _selectedEntityId = id),
                    onTransformCommitted: _commitViewportTransform,
                    enableRenderer: widget.enableRenderer,
                  ),
                ),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 340,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SchemaInspectorPanel(
                          key: ValueKey(
                            '${_selectedEntityId?.value}-${_session.revision}',
                          ),
                          entity: _selectedEntity,
                          world: _world,
                          registry: _schemas,
                          onFieldChanged: _setField,
                          onAddComponent: _addComponent,
                          onRemoveComponent: _removeComponent,
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        flex: 2,
                        child: ValidationPanel(report: _validation),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            key: const Key('forge_status'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Text(
              'Stage 10.2 · ${_world.allEntities.length} entities · $location · '
              '${_session.historyEstimatedBytes} undo bytes · $_status',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    return PopScope(
      canPop: _allowPop || !_session.isDirty,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: scaffold,
    );
  }
}

String _safeFileName(String value) {
  final sanitized = value
      .trim()
      .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return sanitized.isEmpty ? 'avarra_project' : sanitized;
}
