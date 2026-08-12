import 'dart:async';
import 'dart:math' as math;

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_creator_api/avarra_creator_api.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';

import 'src/forge_file_services.dart';
import 'src/forge_sample_world.dart';

void main() {
  runApp(const AvarraForgeApp());
}

class AvarraForgeApp extends StatelessWidget {
  const AvarraForgeApp({
    this.initialWorld,
    this.projectStorage,
    this.fileDialogs = const PlatformForgeFileDialogs(),
    super.key,
  });

  final WorldDefinition? initialWorld;
  final ForgeProjectStorage? projectStorage;
  final ForgeFileDialogs fileDialogs;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Avarra Forge',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFFD79A5B),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: ForgeWorkspaceScreen(
        initialWorld: initialWorld ?? createForgeStarterWorld(),
        projectStorage: projectStorage ?? ForgeProjectFileStorage(),
        fileDialogs: fileDialogs,
      ),
    );
  }
}

class ForgeWorkspaceScreen extends StatefulWidget {
  const ForgeWorkspaceScreen({
    required this.initialWorld,
    required this.projectStorage,
    required this.fileDialogs,
    super.key,
  });

  final WorldDefinition initialWorld;
  final ForgeProjectStorage projectStorage;
  final ForgeFileDialogs fileDialogs;

  @override
  State<ForgeWorkspaceScreen> createState() => _ForgeWorkspaceScreenState();
}

class _ForgeWorkspaceScreenState extends State<ForgeWorkspaceScreen> {
  final ForgeProjectCodec _projectCodec = ForgeProjectCodec();
  final WorldPackageCodec _worldCodec = WorldPackageCodec();
  late CreatorWorldSession _session;
  EntityId? _selectedEntityId;
  String? _projectPath;
  String _status = 'Ready · canonical world is valid';
  bool _busy = false;
  bool _allowPop = false;
  Timer? _recoveryTimer;

  WorldDefinition get _world => _session.world;

  WorldEntityDefinition? get _selectedEntity {
    final selectedId = _selectedEntityId;
    if (selectedId == null) {
      return null;
    }
    return _world.allEntities
        .where((entity) => entity.id == selectedId)
        .firstOrNull;
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_session.isDirty) {
      return true;
    }
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
    if (!await widget.projectStorage.exists(path) || !mounted) {
      return true;
    }
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
  }

  Future<void> _newProject() async {
    if (!await _confirmDiscardChanges() || !mounted) {
      return;
    }
    setState(() {
      _replaceProject(createForgeStarterWorld(), path: null);
      _status = 'New unsaved Relay Zero starter project';
    });
  }

  Future<void> _openProject() async {
    if (!await _confirmDiscardChanges()) {
      return;
    }
    final path = await widget.fileDialogs.openProjectPath();
    if (path == null || !mounted) {
      return;
    }
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
      if (mounted) {
        setState(() {
          _status = 'Open failed: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _saveProject({bool saveAs = false}) async {
    var path = saveAs ? null : _projectPath;
    if (path == null) {
      path = await widget.fileDialogs.chooseSavePath(
        kind: ForgeSaveKind.project,
        suggestedName: '${_safeFileName(_world.name)}.avarra-forge',
      );
      if (path == null || !mounted) {
        return;
      }
      path = ensureForgeFileExtension(path, ForgeSaveKind.project);
      if (!await _confirmOverwrite(path)) {
        return;
      }
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
      if (mounted) {
        setState(() {
          _status = 'Save failed: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _scheduleRecovery() {
    final path = _projectPath;
    if (path == null || !_session.isDirty) {
      return;
    }
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final source = _projectCodec.encodeCanonical(
          ForgeProject(world: _world),
        );
        await widget.projectStorage.writeRecovery(path, source);
        if (mounted) {
          setState(() {
            _status = 'Recovery snapshot updated';
          });
        }
      } on Object catch (error) {
        if (mounted) {
          setState(() {
            _status = 'Recovery snapshot failed: $error';
          });
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _session = CreatorWorldSession(initialWorld: widget.initialWorld);
    _selectedEntityId = _world.allEntities.firstOrNull?.id;
  }

  @override
  void dispose() {
    _recoveryTimer?.cancel();
    super.dispose();
  }

  void _execute(CreatorCommand command, {EntityId? select}) {
    try {
      _session.execute(command);
      setState(() {
        _selectedEntityId = select ?? _selectedEntityId;
        _status = '${command.description} · revision ${_session.revision}';
      });
      _scheduleRecovery();
    } on AvarraException catch (error) {
      setState(() {
        _status = '${error.code.value}: ${error.message}';
      });
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
    if (selectedId == null) {
      return;
    }
    _execute(DeleteEntityCommand(selectedId));
    setState(() {
      _selectedEntityId = _world.allEntities.firstOrNull?.id;
    });
  }

  void _undo() {
    if (!_session.undo()) {
      return;
    }
    setState(() {
      if (_selectedEntity == null) {
        _selectedEntityId = _world.allEntities.firstOrNull?.id;
      }
      _status = 'Undo · revision ${_session.revision}';
    });
    _scheduleRecovery();
  }

  void _redo() {
    if (!_session.redo()) {
      return;
    }
    setState(() {
      _status = 'Redo · revision ${_session.revision}';
    });
    _scheduleRecovery();
  }

  void _validate() {
    final report = _session.validate(requirePlayableEntry: true);
    setState(() {
      _status = report.isValid
          ? 'Validation passed · ready for Game import'
          : '${report.issues.length} validation issue(s) · '
                '${report.issues.first.message}';
    });
  }

  Future<void> _export() async {
    var path = await widget.fileDialogs.chooseSavePath(
      kind: ForgeSaveKind.worldExport,
      suggestedName: '${_safeFileName(_world.name)}.avarra',
    );
    if (path == null || !mounted) {
      return;
    }
    path = ensureForgeFileExtension(path, ForgeSaveKind.worldExport);
    if (!await _confirmOverwrite(path) || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Exporting…';
    });
    try {
      final source = _session.exportCanonical();
      await widget.projectStorage.writeAtomic(path, source, overwrite: true);
      if (mounted) {
        setState(() {
          _status = 'Exported ${source.length} bytes to $path';
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _status = 'Export failed: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _handlePop(bool didPop) async {
    if (didPop || _allowPop || !mounted) {
      return;
    }
    if (await _confirmDiscardChanges() && mounted) {
      setState(() {
        _allowPop = true;
      });
      Navigator.of(context).pop();
    }
  }

  void _setTransform(TransformDefinition transform) {
    final selectedId = _selectedEntityId;
    if (selectedId == null) {
      return;
    }
    _execute(
      SetEntityTransformCommand(entityId: selectedId, transform: transform),
    );
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
            onPressed: _busy ? null : _export,
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
                  width: 250,
                  child: _HierarchyPanel(
                    world: _world,
                    selectedEntityId: _selectedEntityId,
                    onSelected: (id) => setState(() {
                      _selectedEntityId = id;
                    }),
                    onAdd: _addCube,
                    onDelete: _deleteSelected,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _ForgeViewport(
                    world: _world,
                    selectedEntityId: _selectedEntityId,
                    onSelected: (id) => setState(() {
                      _selectedEntityId = id;
                    }),
                  ),
                ),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 310,
                  child: _InspectorPanel(
                    key: ValueKey(
                      '${_selectedEntityId?.value}-${_session.revision}',
                    ),
                    entity: _selectedEntity,
                    onTransformChanged: _setTransform,
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
              'Stage 10.1B · ${_world.allEntities.length} entities · '
              '$location · $_status',
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

class _HierarchyPanel extends StatelessWidget {
  const _HierarchyPanel({
    required this.world,
    required this.selectedEntityId,
    required this.onSelected,
    required this.onAdd,
    required this.onDelete,
  });

  final WorldDefinition world;
  final EntityId? selectedEntityId;
  final ValueChanged<EntityId> onSelected;
  final VoidCallback onAdd;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final entities = world.allEntities.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelTitle('Hierarchy'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  key: const Key('add_cube'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Add cube'),
                ),
              ),
              IconButton(
                key: const Key('delete_entity'),
                tooltip: 'Delete selected entity',
                onPressed: selectedEntityId == null ? null : onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: entities.length,
            itemBuilder: (context, index) {
              final entity = entities[index];
              return ListTile(
                key: Key('entity_${entity.id.value}'),
                dense: true,
                selected: entity.id == selectedEntityId,
                leading: Icon(_entityIcon(entity), size: 20),
                title: Text(_entityLabel(entity)),
                subtitle: Text(
                  entity.id.value.substring(entity.id.value.length - 8),
                ),
                onTap: () => onSelected(entity.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ForgeViewport extends StatelessWidget {
  const _ForgeViewport({
    required this.world,
    required this.selectedEntityId,
    required this.onSelected,
  });

  final WorldDefinition world;
  final EntityId? selectedEntityId;
  final ValueChanged<EntityId> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return ColoredBox(
          color: const Color(0xFF20262B),
          child: GestureDetector(
            key: const Key('forge_viewport'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final hit = _pickEntity(world, size, details.localPosition);
              if (hit != null) {
                onSelected(hit);
              }
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ForgeViewportPainter(
                      world: world,
                      selectedEntityId: selectedEntityId,
                      gridColor: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.18),
                      entityColor: Theme.of(context).colorScheme.primary,
                      selectedColor: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ),
                const Positioned(
                  top: 12,
                  left: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xB312171B),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Text(
                        'Isometric schematic viewport\n'
                        'Select markers or use the hierarchy',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.entity,
    required this.onTransformChanged,
    super.key,
  });

  final WorldEntityDefinition? entity;
  final ValueChanged<TransformDefinition> onTransformChanged;

  @override
  Widget build(BuildContext context) {
    final value = entity;
    if (value == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelTitle('Inspector'),
          Center(child: Text('No selection')),
        ],
      );
    }
    final transform = value.component<TransformDefinition>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        const _PanelTitle('Inspector'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SelectableText(
            value.id.value,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final type in value.components.keys)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_shortComponentName(type)),
                ),
            ],
          ),
        ),
        if (transform != null) ...[
          const Divider(height: 24),
          _TransformEditor(transform: transform, onChanged: onTransformChanged),
        ],
      ],
    );
  }
}

class _TransformEditor extends StatelessWidget {
  const _TransformEditor({required this.transform, required this.onChanged});

  final TransformDefinition transform;
  final ValueChanged<TransformDefinition> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transform', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _VectorFields(
            label: 'Position',
            keyPrefix: 'position',
            values: [
              transform.position.x,
              transform.position.y,
              transform.position.z,
            ],
            axisLabels: const ['X', 'Y', 'Z'],
            onChanged: (index, number) {
              final values = [
                transform.position.x,
                transform.position.y,
                transform.position.z,
              ]..[index] = number;
              onChanged(
                TransformDefinition(
                  position: ContentVector3(values[0], values[1], values[2]),
                  rotation: transform.rotation,
                  scale: transform.scale,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _VectorFields(
            label: 'Rotation quaternion',
            keyPrefix: 'rotation',
            values: [
              transform.rotation.x,
              transform.rotation.y,
              transform.rotation.z,
              transform.rotation.w,
            ],
            axisLabels: const ['X', 'Y', 'Z', 'W'],
            onChanged: (index, number) {
              final values = [
                transform.rotation.x,
                transform.rotation.y,
                transform.rotation.z,
                transform.rotation.w,
              ]..[index] = number;
              onChanged(
                TransformDefinition(
                  position: transform.position,
                  rotation: ContentQuaternion(
                    values[0],
                    values[1],
                    values[2],
                    values[3],
                  ),
                  scale: transform.scale,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _VectorFields(
            label: 'Scale',
            keyPrefix: 'scale',
            values: [transform.scale.x, transform.scale.y, transform.scale.z],
            axisLabels: const ['X', 'Y', 'Z'],
            onChanged: (index, number) {
              final values = [
                transform.scale.x,
                transform.scale.y,
                transform.scale.z,
              ]..[index] = number;
              onChanged(
                TransformDefinition(
                  position: transform.position,
                  rotation: transform.rotation,
                  scale: ContentVector3(values[0], values[1], values[2]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VectorFields extends StatelessWidget {
  const _VectorFields({
    required this.label,
    required this.keyPrefix,
    required this.values,
    required this.axisLabels,
    required this.onChanged,
  });

  final String label;
  final String keyPrefix;
  final List<double> values;
  final List<String> axisLabels;
  final void Function(int index, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 5),
        Row(
          children: [
            for (var index = 0; index < values.length; index += 1) ...[
              if (index > 0) const SizedBox(width: 5),
              Expanded(
                child: TextFormField(
                  key: Key('${keyPrefix}_${axisLabels[index].toLowerCase()}'),
                  initialValue: _formatNumber(values[index]),
                  decoration: InputDecoration(labelText: axisLabels[index]),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  onFieldSubmitted: (value) {
                    final parsed = double.tryParse(value);
                    if (parsed != null && parsed.isFinite) {
                      onChanged(index, parsed);
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 9),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _PlacedEntity {
  const _PlacedEntity({required this.entity, required this.position});

  final WorldEntityDefinition entity;
  final ContentVector3 position;
}

class _ForgeViewportPainter extends CustomPainter {
  const _ForgeViewportPainter({
    required this.world,
    required this.selectedEntityId,
    required this.gridColor,
    required this.entityColor,
    required this.selectedColor,
  });

  final WorldDefinition world;
  final EntityId? selectedEntityId;
  final Color gridColor;
  final Color entityColor;
  final Color selectedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var coordinate = -12; coordinate <= 12; coordinate += 1) {
      final left = _project(
        ContentVector3(coordinate.toDouble(), 0, -12),
        size,
      );
      final right = _project(
        ContentVector3(coordinate.toDouble(), 0, 12),
        size,
      );
      final top = _project(ContentVector3(-12, 0, coordinate.toDouble()), size);
      final bottom = _project(
        ContentVector3(12, 0, coordinate.toDouble()),
        size,
      );
      canvas.drawLine(left, right, gridPaint);
      canvas.drawLine(top, bottom, gridPaint);
    }
    canvas.drawCircle(center, 2, Paint()..color = gridColor);

    for (final placed in _placedEntities(world)) {
      final point = _project(placed.position, size);
      final selected = placed.entity.id == selectedEntityId;
      final player =
          placed.entity.component<PlayerControlledDefinition>() != null;
      final paint = Paint()
        ..color = selected ? selectedColor : entityColor
        ..style = selected ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 3;
      if (player) {
        canvas.drawCircle(point, selected ? 11 : 8, paint);
      } else {
        final radius = selected ? 10.0 : 7.0;
        canvas.drawRect(
          Rect.fromCenter(center: point, width: radius * 2, height: radius * 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ForgeViewportPainter oldDelegate) {
    return oldDelegate.world != world ||
        oldDelegate.selectedEntityId != selectedEntityId ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.entityColor != entityColor ||
        oldDelegate.selectedColor != selectedColor;
  }
}

List<_PlacedEntity> _placedEntities(WorldDefinition world) {
  final result = <_PlacedEntity>[];
  for (final entity in world.entities) {
    final transform = entity.component<TransformDefinition>();
    if (transform != null) {
      result.add(_PlacedEntity(entity: entity, position: transform.position));
    }
  }
  final chunkSize = world.chunkSize ?? 0;
  for (final chunk in world.chunks) {
    for (final entity in chunk.entities) {
      final transform = entity.component<TransformDefinition>();
      if (transform != null) {
        result.add(
          _PlacedEntity(
            entity: entity,
            position: ContentVector3(
              transform.position.x + chunk.coordinate.x * chunkSize,
              transform.position.y,
              transform.position.z + chunk.coordinate.z * chunkSize,
            ),
          ),
        );
      }
    }
  }
  return result;
}

Offset _project(ContentVector3 point, Size size) {
  const scale = 28.0;
  return Offset(
    size.width / 2 + (point.x - point.z) * scale,
    size.height / 2 + (point.x + point.z) * scale * 0.5 - point.y * scale,
  );
}

EntityId? _pickEntity(WorldDefinition world, Size size, Offset pointer) {
  EntityId? best;
  var bestDistance = double.infinity;
  for (final placed in _placedEntities(world)) {
    final distance = (_project(placed.position, size) - pointer).distance;
    if (distance < 18 && distance < bestDistance) {
      best = placed.entity.id;
      bestDistance = distance;
    }
  }
  return best;
}

String _entityLabel(WorldEntityDefinition entity) {
  if (entity.component<PlayerControlledDefinition>() != null) {
    return 'Player';
  }
  final interactable = entity.component<InteractableDefinition>();
  if (interactable != null) {
    return interactable.label;
  }
  final transform = entity.component<TransformDefinition>();
  if (transform != null &&
      math.max(transform.scale.x, transform.scale.z) >= 4) {
    return 'Ground';
  }
  return 'Entity';
}

IconData _entityIcon(WorldEntityDefinition entity) {
  if (entity.component<PlayerControlledDefinition>() != null) {
    return Icons.person_outline;
  }
  if (entity.component<InteractableDefinition>() != null) {
    return Icons.touch_app_outlined;
  }
  return Icons.view_in_ar_outlined;
}

String _shortComponentName(String type) {
  return type.split('.').last.replaceAll('_', ' ');
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
}

String _safeFileName(String value) {
  final sanitized = value
      .trim()
      .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return sanitized.isEmpty ? 'avarra_project' : sanitized;
}
