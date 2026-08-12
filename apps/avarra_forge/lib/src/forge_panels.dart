import 'dart:math' as math;

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_creator_api/avarra_creator_api.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';

typedef ForgeFieldChanged =
    void Function(String componentType, String fieldName, Object? value);

final class HierarchyPanel extends StatelessWidget {
  const HierarchyPanel({
    required this.world,
    required this.selectedEntityId,
    required this.onSelected,
    required this.onAdd,
    required this.onDelete,
    super.key,
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
        const PanelTitle('Hierarchy'),
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
                subtitle: Text(entity.id.value.substring(28)),
                onTap: () => onSelected(entity.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

final class SchemaInspectorPanel extends StatelessWidget {
  const SchemaInspectorPanel({
    required this.entity,
    required this.world,
    required this.registry,
    required this.onFieldChanged,
    required this.onAddComponent,
    required this.onRemoveComponent,
    super.key,
  });

  final WorldEntityDefinition? entity;
  final WorldDefinition world;
  final ComponentSchemaRegistry registry;
  final ForgeFieldChanged onFieldChanged;
  final ValueChanged<String> onAddComponent;
  final ValueChanged<String> onRemoveComponent;

  @override
  Widget build(BuildContext context) {
    final selected = entity;
    if (selected == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelTitle('Inspector'),
          Center(child: Text('No selection')),
        ],
      );
    }
    final addable = registry.schemas
        .where(
          (schema) =>
              (schema.creatableWithoutContext ||
                  (schema.type == AvarraComponentType.renderableReference &&
                      world.assets.isNotEmpty)) &&
              !selected.components.containsKey(schema.type),
        )
        .toList();
    final components = selected.components.values.toList()
      ..sort((left, right) {
        final leftSchema = registry.schemaFor(left.type);
        final rightSchema = registry.schemaFor(right.type);
        final order = (leftSchema?.editorOrder ?? 100).compareTo(
          rightSchema?.editorOrder ?? 100,
        );
        return order != 0 ? order : left.type.compareTo(right.type);
      });
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Row(
          children: [
            const Expanded(child: PanelTitle('Inspector')),
            PopupMenuButton<String>(
              key: const Key('add_component'),
              tooltip: 'Add component',
              enabled: addable.isNotEmpty,
              onSelected: onAddComponent,
              itemBuilder: (context) => [
                for (final schema in addable)
                  PopupMenuItem(value: schema.type, child: Text(schema.label)),
              ],
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SelectableText(
            selected.id.value,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
        for (final component in components)
          _ComponentEditor(
            component: component,
            schema: registry.schemaFor(component.type),
            assets: world.assets,
            onChanged: onFieldChanged,
            onRemove: () => onRemoveComponent(component.type),
          ),
      ],
    );
  }
}

final class _ComponentEditor extends StatelessWidget {
  const _ComponentEditor({
    required this.component,
    required this.schema,
    required this.assets,
    required this.onChanged,
    required this.onRemove,
  });

  final ContentComponentDefinition component;
  final ComponentSchema? schema;
  final List<WorldAssetDefinition> assets;
  final ForgeFieldChanged onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final definition = schema;
    if (definition == null) {
      return ListTile(
        title: Text(component.type),
        subtitle: const Text('No editor schema is installed.'),
      );
    }
    final data = component.toJson();
    return ExpansionTile(
      initiallyExpanded: component.type == AvarraComponentType.transform,
      title: Text(definition.label),
      subtitle: definition.help == null ? null : Text(definition.help!),
      trailing: IconButton(
        key: Key('remove_${component.type}'),
        tooltip: 'Remove ${definition.label}',
        onPressed: onRemove,
        icon: const Icon(Icons.remove_circle_outline),
      ),
      children: [
        for (final field in definition.fields)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 9),
            child: _SchemaFieldEditor(
              componentType: component.type,
              field: field,
              value: data[field.name],
              assets: assets,
              onChanged: (value) =>
                  onChanged(component.type, field.name, value),
            ),
          ),
        if (definition.fields.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Marker component · no editable fields'),
            ),
          ),
      ],
    );
  }
}

final class _SchemaFieldEditor extends StatelessWidget {
  const _SchemaFieldEditor({
    required this.componentType,
    required this.field,
    required this.value,
    required this.assets,
    required this.onChanged,
  });

  final String componentType;
  final ComponentFieldSchema field;
  final Object? value;
  final List<WorldAssetDefinition> assets;
  final ValueChanged<Object?> onChanged;

  String get _keyPrefix => componentType == AvarraComponentType.transform
      ? field.name
      : '${componentType.split('.').last}_${field.name}';

  @override
  Widget build(BuildContext context) {
    return switch (field.kind) {
      ComponentFieldKind.number => _numberField(value as num),
      ComponentFieldKind.string => _stringField(value as String),
      ComponentFieldKind.boolean => SwitchListTile(
        key: Key(_keyPrefix),
        contentPadding: EdgeInsets.zero,
        title: Text(field.label),
        subtitle: field.help == null ? null : Text(field.help!),
        value: value as bool,
        onChanged: onChanged,
      ),
      ComponentFieldKind.vector3 => _vectorField(
        (value as List<dynamic>).cast<num>(),
        const ['X', 'Y', 'Z'],
      ),
      ComponentFieldKind.quaternion => _vectorField(
        (value as List<dynamic>).cast<num>(),
        const ['X', 'Y', 'Z', 'W'],
      ),
      ComponentFieldKind.stableId => _stableIdField(value as String),
      ComponentFieldKind.booleanMap => _booleanMapField(
        Map<String, dynamic>.from(value! as Map),
      ),
    };
  }

  Widget _numberField(num number) {
    return TextFormField(
      key: Key(_keyPrefix),
      initialValue: _formatNumber(number.toDouble()),
      decoration: InputDecoration(
        labelText: field.label,
        helperText: _rangeHelp,
      ),
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      onFieldSubmitted: (text) {
        final parsed = double.tryParse(text);
        if (parsed != null && parsed.isFinite) onChanged(parsed);
      },
    );
  }

  String? get _rangeHelp {
    if (field.help != null) return field.help;
    if (field.minimum != null && field.maximum != null) {
      return '${field.minimum} to ${field.maximum}';
    }
    if (field.minimum != null) return 'Minimum ${field.minimum}';
    if (field.maximum != null) return 'Maximum ${field.maximum}';
    return null;
  }

  Widget _stringField(String text) {
    final allowed = field.allowedStringValues;
    if (allowed != null) {
      final values = allowed.toList()..sort();
      return DropdownButtonFormField<String>(
        key: Key(_keyPrefix),
        initialValue: text,
        decoration: InputDecoration(labelText: field.label),
        items: [
          for (final option in values)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      );
    }
    return TextFormField(
      key: Key(_keyPrefix),
      initialValue: text,
      maxLength: field.maximumLength,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.help,
      ),
      onFieldSubmitted: onChanged,
    );
  }

  Widget _vectorField(List<num> numbers, List<String> axes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.label),
        if (field.help != null) Text(field.help!),
        const SizedBox(height: 5),
        Row(
          children: [
            for (var index = 0; index < numbers.length; index += 1) ...[
              if (index > 0) const SizedBox(width: 5),
              Expanded(
                child: TextFormField(
                  key: Key('${_keyPrefix}_${axes[index].toLowerCase()}'),
                  initialValue: _formatNumber(numbers[index].toDouble()),
                  decoration: InputDecoration(labelText: axes[index]),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  onFieldSubmitted: (text) {
                    final parsed = double.tryParse(text);
                    if (parsed == null || !parsed.isFinite) return;
                    final next = numbers
                        .map((entry) => entry.toDouble())
                        .toList();
                    next[index] = parsed;
                    onChanged(next);
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _stableIdField(String id) {
    if (field.stableIdDomain == StableIdDomain.asset) {
      return DropdownButtonFormField<String>(
        key: Key(_keyPrefix),
        initialValue: id,
        decoration: InputDecoration(labelText: field.label),
        items: [
          for (final asset in assets)
            DropdownMenuItem(value: asset.id.value, child: Text(asset.path)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      );
    }
    return TextFormField(
      key: Key(_keyPrefix),
      initialValue: id,
      decoration: InputDecoration(labelText: field.label),
      onFieldSubmitted: onChanged,
    );
  }

  Widget _booleanMapField(Map<String, dynamic> values) {
    final encoded = values.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    return TextFormField(
      key: Key(_keyPrefix),
      initialValue: encoded,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: 'Comma-separated key=true or key=false entries',
      ),
      onFieldSubmitted: (text) {
        final result = <String, bool>{};
        for (final item in text.split(',')) {
          final parts = item.trim().split('=');
          if (parts.length != 2 ||
              (parts[1] != 'true' && parts[1] != 'false')) {
            return;
          }
          result[parts[0]] = parts[1] == 'true';
        }
        onChanged(result);
      },
    );
  }
}

final class ValidationPanel extends StatelessWidget {
  const ValidationPanel({required this.report, super.key});

  final CreatorValidationReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelTitle(
          report.isValid
              ? 'Validation · ready'
              : 'Validation · ${report.errorCount} error(s)',
        ),
        Expanded(
          child: report.issues.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('No issues. The project is ready to export.'),
                )
              : ListView.builder(
                  key: const Key('validation_issues'),
                  itemCount: report.issues.length,
                  itemBuilder: (context, index) {
                    final issue = report.issues[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        issue.blocksExport
                            ? Icons.error_outline
                            : Icons.warning_amber_outlined,
                        color: issue.blocksExport
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      title: Text(issue.message),
                      subtitle: Text(
                        [
                          issue.code.value,
                          if (issue.location.isNotEmpty) issue.location,
                          ?issue.suggestedRepair,
                        ].join('\n'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

final class PanelTitle extends StatelessWidget {
  const PanelTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 9),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

String _entityLabel(WorldEntityDefinition entity) {
  if (entity.component<PlayerControlledDefinition>() != null) return 'Player';
  final interactable = entity.component<InteractableDefinition>();
  if (interactable != null) return interactable.label;
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

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
