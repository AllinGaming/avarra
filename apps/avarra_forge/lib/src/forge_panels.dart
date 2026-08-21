import 'dart:math' as math;

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_creator_api/avarra_creator_api.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';

import 'forge_palette.dart';

typedef ForgeFieldChanged =
    void Function(String componentType, String fieldName, Object? value);

const String _customGuardianMissionProfileId = 'custom';

final class ObjectPalettePanel extends StatelessWidget {
  const ObjectPalettePanel({
    required this.items,
    required this.world,
    required this.assets,
    required this.selectedItem,
    required this.selectedAssetId,
    required this.selectedGuardianEntityId,
    required this.selectedCollectibleItemId,
    required this.guardianMissionTemplateActive,
    required this.guardianMissionSettings,
    required this.guardianMissionProfileId,
    required this.guardianMissionProfileRevision,
    required this.guardianMissionAssets,
    required this.brushMode,
    required this.onSelected,
    required this.onAssetSelected,
    required this.onGuardianReferenceSelected,
    required this.onCollectibleReferenceSelected,
    required this.onGuardianMissionTemplateSelected,
    required this.onGuardianMissionSettingsChanged,
    required this.onGuardianMissionProfileSelected,
    required this.onGuardianMissionAssetsChanged,
    required this.onBrushModeSelected,
    required this.onSelectionTool,
    super.key,
  });

  final List<ForgePaletteItem> items;
  final WorldDefinition world;
  final List<WorldAssetDefinition> assets;
  final ForgePaletteItem? selectedItem;
  final AssetId? selectedAssetId;
  final EntityId? selectedGuardianEntityId;
  final String? selectedCollectibleItemId;
  final bool guardianMissionTemplateActive;
  final ForgeGuardianMissionSettings guardianMissionSettings;
  final String? guardianMissionProfileId;
  final int guardianMissionProfileRevision;
  final ForgeGuardianMissionAssets? guardianMissionAssets;
  final ForgeBrushMode brushMode;
  final ValueChanged<ForgePaletteItem?> onSelected;
  final ValueChanged<AssetId> onAssetSelected;
  final ValueChanged<EntityId> onGuardianReferenceSelected;
  final ValueChanged<String> onCollectibleReferenceSelected;
  final VoidCallback onGuardianMissionTemplateSelected;
  final ValueChanged<ForgeGuardianMissionSettings>
  onGuardianMissionSettingsChanged;
  final ValueChanged<String> onGuardianMissionProfileSelected;
  final ValueChanged<ForgeGuardianMissionAssets> onGuardianMissionAssetsChanged;
  final ValueChanged<ForgeBrushMode> onBrushModeSelected;
  final VoidCallback onSelectionTool;

  @override
  Widget build(BuildContext context) {
    final hasRenderableAsset = assets.isNotEmpty && selectedAssetId != null;
    final guardians = forgeGuardianEntities(world);
    final collectibles = forgeCollectibleEntities(world);
    final missionTemplateIssue = forgeGuardianMissionTemplateIssue(
      world,
      settings: guardianMissionSettings,
      assets: guardianMissionAssets,
    );
    final references = ForgePalettePlacementReferences(
      guardianEntityId: selectedGuardianEntityId,
      collectibleItemId: selectedCollectibleItemId,
    );
    final selectedPlacementIssue = selectedItem?.placementIssue(
      world,
      references,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: PanelTitle('Object palette')),
            IconButton(
              key: const Key('palette_select_tool'),
              tooltip: 'Selection tool',
              onPressed:
                  selectedItem == null &&
                      !guardianMissionTemplateActive &&
                      brushMode == ForgeBrushMode.none
                  ? null
                  : onSelectionTool,
              icon: const Icon(Icons.near_me_outlined),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Catalog asset',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AssetId>(
                key: const Key('palette_asset'),
                value: selectedAssetId,
                isDense: true,
                isExpanded: true,
                hint: const Text('No world assets'),
                items: [
                  for (final asset in assets)
                    DropdownMenuItem(
                      value: asset.id,
                      child: Text(
                        _assetLabel(asset),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (assetId) {
                  if (assetId != null) onAssetSelected(assetId);
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Guardian ref',
                    prefixIcon: Icon(Icons.shield_outlined),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<EntityId>(
                      key: const Key('palette_guardian_reference'),
                      value: selectedGuardianEntityId,
                      isDense: true,
                      isExpanded: true,
                      hint: const Text('None'),
                      items: [
                        for (final guardian in guardians)
                          DropdownMenuItem(
                            value: guardian.id,
                            child: Text(
                              _shortEntityReference(guardian),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (entityId) {
                        if (entityId != null) {
                          onGuardianReferenceSelected(entityId);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Loot ref',
                    prefixIcon: Icon(Icons.diamond_outlined),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('palette_collectible_reference'),
                      value: selectedCollectibleItemId,
                      isDense: true,
                      isExpanded: true,
                      hint: const Text('None'),
                      items: [
                        for (final collectible in collectibles)
                          DropdownMenuItem(
                            value: collectible
                                .component<CollectibleItemDefinition>()!
                                .itemId,
                            child: Text(
                              collectible
                                  .component<CollectibleItemDefinition>()!
                                  .itemLabel,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (itemId) {
                        if (itemId != null) {
                          onCollectibleReferenceSelected(itemId);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  key: const Key('brush_paint_floor'),
                  label: const Text('Paint floor'),
                  avatar: const Icon(Icons.brush_outlined, size: 18),
                  selected: brushMode == ForgeBrushMode.paintFloor,
                  onSelected: hasRenderableAsset
                      ? (selected) => onBrushModeSelected(
                          selected
                              ? ForgeBrushMode.paintFloor
                              : ForgeBrushMode.none,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ChoiceChip(
                  key: const Key('brush_erase_floor'),
                  label: const Text('Erase'),
                  avatar: const Icon(Icons.auto_fix_off_outlined, size: 18),
                  selected: brushMode == ForgeBrushMode.eraseFloor,
                  onSelected: (selected) => onBrushModeSelected(
                    selected ? ForgeBrushMode.eraseFloor : ForgeBrushMode.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
          child: Text(
            !hasRenderableAsset
                ? 'This world has no renderable asset for palette objects.'
                : guardianMissionTemplateActive
                ? missionTemplateIssue ??
                      'Placing combat mission - one click creates one linked chain'
                : selectedPlacementIssue ??
                      (brushMode == ForgeBrushMode.paintFloor
                          ? 'Painting floor · drag across the viewport'
                          : brushMode == ForgeBrushMode.eraseFloor
                          ? 'Erasing authored floor tiles · drag across the viewport'
                          : selectedItem == null
                          ? 'Choose an object, then click the viewport.'
                          : 'Placing ${selectedItem!.label} · '
                                '${selectedItem!.placementGridSize} unit grid'),
            key: const Key('palette_status'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: ListView(
            key: const Key('object_palette'),
            children: [
              Padding(
                key: const Key('palette_category_templates'),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                child: Text(
                  'MISSION TEMPLATES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              if (guardianMissionTemplateActive)
                _guardianMissionSettingsCard(context),
              ListTile(
                key: const Key('palette_guardian_mission'),
                dense: true,
                enabled: hasRenderableAsset && missionTemplateIssue == null,
                selected: guardianMissionTemplateActive,
                leading: const Icon(Icons.account_tree_outlined, size: 20),
                title: const Text('Combat mission'),
                subtitle: Text(
                  missionTemplateIssue ??
                      'Guardian + guarded loot + completion console',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: guardianMissionTemplateActive
                    ? const Icon(Icons.add_location_alt_outlined, size: 20)
                    : null,
                onTap: hasRenderableAsset && missionTemplateIssue == null
                    ? onGuardianMissionTemplateSelected
                    : null,
              ),
              for (final category in ForgePaletteItemCategory.values) ...[
                Padding(
                  key: Key('palette_category_${category.name}'),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                  child: Text(
                    _paletteCategoryLabel(category),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                for (final item in items.where(
                  (item) => item.category == category,
                ))
                  _paletteItemTile(
                    item: item,
                    hasRenderableAsset: hasRenderableAsset,
                    references: references,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _guardianMissionSettingsCard(BuildContext context) {
    return Card(
      key: const Key('guardian_mission_settings'),
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Template settings',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Encounter profile',
                prefixIcon: Icon(Icons.tune_outlined),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const Key('mission_profile'),
                  value:
                      guardianMissionProfileId ??
                      _customGuardianMissionProfileId,
                  isDense: true,
                  isExpanded: true,
                  items: [
                    for (final profile in forgeGuardianMissionProfiles)
                      DropdownMenuItem(
                        value: profile.id,
                        child: Text(
                          '${profile.label} - ${profile.description}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const DropdownMenuItem(
                      value: _customGuardianMissionProfileId,
                      enabled: false,
                      child: Text('Custom tuning'),
                    ),
                  ],
                  onChanged: (profileId) {
                    if (profileId != null &&
                        profileId != _customGuardianMissionProfileId) {
                      onGuardianMissionProfileSelected(profileId);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(
                      'mission_guardian_health:'
                      '$guardianMissionProfileRevision',
                    ),
                    child: _missionNumberField(
                      keyName: 'mission_guardian_health',
                      label: 'Health',
                      value: guardianMissionSettings.guardianMaximumHealth,
                      onChanged: (value) => onGuardianMissionSettingsChanged(
                        guardianMissionSettings.copyWith(
                          guardianMaximumHealth: value,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(
                      'mission_guardian_damage:'
                      '$guardianMissionProfileRevision',
                    ),
                    child: _missionNumberField(
                      keyName: 'mission_guardian_damage',
                      label: 'Damage',
                      value: guardianMissionSettings.guardianDamage,
                      onChanged: (value) => onGuardianMissionSettingsChanged(
                        guardianMissionSettings.copyWith(guardianDamage: value),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: ValueKey('mission_spacing:$guardianMissionProfileRevision'),
              child: _missionNumberField(
                keyName: 'mission_spacing',
                label: 'Center spacing',
                value: guardianMissionSettings.spacing,
                onChanged: (value) => onGuardianMissionSettingsChanged(
                  guardianMissionSettings.copyWith(spacing: value),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('mission_item_label'),
              initialValue: guardianMissionSettings.itemLabel,
              maxLength: 80,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Item label',
              ),
              onChanged: (value) => onGuardianMissionSettingsChanged(
                guardianMissionSettings.copyWith(itemLabel: value),
              ),
            ),
            TextFormField(
              key: const Key('mission_completion_label'),
              initialValue: guardianMissionSettings.completionLabel,
              maxLength: 80,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Completion label',
              ),
              onChanged: (value) => onGuardianMissionSettingsChanged(
                guardianMissionSettings.copyWith(completionLabel: value),
              ),
            ),
            if (guardianMissionAssets case final missionAssets?) ...[
              const SizedBox(height: 4),
              Text(
                'Role assets',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              _missionAssetField(
                keyName: 'mission_guardian_asset',
                label: 'Guardian',
                value: missionAssets.guardianAssetId,
                onChanged: (assetId) => onGuardianMissionAssetsChanged(
                  missionAssets.copyWith(guardianAssetId: assetId),
                ),
              ),
              const SizedBox(height: 6),
              _missionAssetField(
                keyName: 'mission_loot_asset',
                label: 'Loot',
                value: missionAssets.collectibleAssetId,
                onChanged: (assetId) => onGuardianMissionAssetsChanged(
                  missionAssets.copyWith(collectibleAssetId: assetId),
                ),
              ),
              const SizedBox(height: 6),
              _missionAssetField(
                keyName: 'mission_console_asset',
                label: 'Completion console',
                value: missionAssets.completionConsoleAssetId,
                onChanged: (assetId) => onGuardianMissionAssetsChanged(
                  missionAssets.copyWith(completionConsoleAssetId: assetId),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _missionAssetField({
    required String keyName,
    required String label,
    required AssetId value,
    required ValueChanged<AssetId> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(isDense: true, labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AssetId>(
          key: Key(keyName),
          value: value,
          isDense: true,
          isExpanded: true,
          items: [
            for (final asset in assets)
              DropdownMenuItem(
                value: asset.id,
                child: Text(
                  _assetLabel(asset),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (assetId) {
            if (assetId != null) onChanged(assetId);
          },
        ),
      ),
    );
  }

  Widget _missionNumberField({
    required String keyName,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return TextFormField(
      key: Key(keyName),
      initialValue: _formatNumber(value),
      decoration: InputDecoration(isDense: true, labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (text) {
        final parsed = double.tryParse(text);
        if (parsed != null && parsed.isFinite && parsed > 0) {
          onChanged(parsed);
        }
      },
    );
  }

  Widget _paletteItemTile({
    required ForgePaletteItem item,
    required bool hasRenderableAsset,
    required ForgePalettePlacementReferences references,
  }) {
    final issue = item.placementIssue(world, references);
    final enabled = hasRenderableAsset && issue == null;
    return ListTile(
      key: Key('palette_${item.id}'),
      dense: true,
      enabled: enabled,
      selected: item == selectedItem,
      leading: Icon(_paletteIcon(item.kind), size: 20),
      title: Text(item.label),
      subtitle: Text(
        issue ?? item.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: item == selectedItem
          ? const Icon(Icons.add_location_alt_outlined, size: 20)
          : null,
      onTap: enabled ? () => onSelected(item) : null,
    );
  }
}

String _assetLabel(WorldAssetDefinition asset) {
  final normalized = asset.path.replaceAll(r'\', '/');
  final name = normalized.split('/').last;
  return name.isEmpty ? asset.id.value : name;
}

String _shortEntityReference(WorldEntityDefinition entity) =>
    'Guardian ${entity.id.value.substring(28)}';

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
            entities: world.allEntities.toList(growable: false),
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
    required this.entities,
    required this.onChanged,
    required this.onRemove,
  });

  final ContentComponentDefinition component;
  final ComponentSchema? schema;
  final List<WorldAssetDefinition> assets;
  final List<WorldEntityDefinition> entities;
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
              entities: entities,
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
    required this.entities,
    required this.onChanged,
  });

  final String componentType;
  final ComponentFieldSchema field;
  final Object? value;
  final List<WorldAssetDefinition> assets;
  final List<WorldEntityDefinition> entities;
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
    if (componentType == AvarraComponentType.itemTurnIn &&
        field.name == 'requiredItemId') {
      final collectibles = entities
          .map((entity) => entity.component<CollectibleItemDefinition>())
          .whereType<CollectibleItemDefinition>()
          .toList();
      if (collectibles.isNotEmpty) {
        return DropdownButtonFormField<String>(
          key: Key(_keyPrefix),
          initialValue: text,
          decoration: InputDecoration(labelText: field.label),
          items: [
            for (final collectible in collectibles)
              DropdownMenuItem(
                value: collectible.itemId,
                child: Text(collectible.itemLabel),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        );
      }
    }
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
    if (field.stableIdDomain == StableIdDomain.entity) {
      final candidates =
          componentType == AvarraComponentType.collectibleItem &&
              field.name == 'guardedByEntityId'
          ? entities
                .where(
                  (entity) =>
                      entity.component<GuardianBehaviorDefinition>() != null,
                )
                .toList()
          : entities;
      if (candidates.isNotEmpty) {
        return DropdownButtonFormField<String>(
          key: Key(_keyPrefix),
          initialValue: id,
          decoration: InputDecoration(labelText: field.label),
          items: [
            for (final entity in candidates)
              DropdownMenuItem(
                value: entity.id.value,
                child: Text(_entityLabel(entity)),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        );
      }
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
  if (entity.component<GuardianBehaviorDefinition>() != null) {
    return 'Guardian';
  }
  final collectible = entity.component<CollectibleItemDefinition>();
  if (collectible != null) return collectible.itemLabel;
  final turnIn = entity.component<ItemTurnInDefinition>();
  if (turnIn != null) return turnIn.completionLabel;
  final gate = entity.component<ObjectiveGateDefinition>();
  if (gate != null) return gate.label;
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
  if (entity.component<GuardianBehaviorDefinition>() != null) {
    return Icons.shield_outlined;
  }
  if (entity.component<CollectibleItemDefinition>() != null) {
    return Icons.diamond_outlined;
  }
  if (entity.component<ItemTurnInDefinition>() != null) {
    return Icons.flag_outlined;
  }
  if (entity.component<ObjectiveGateDefinition>() != null) {
    return Icons.door_sliding_outlined;
  }
  if (entity.component<ObjectiveDefinition>() != null) {
    return Icons.task_alt_outlined;
  }
  if (entity.component<InteractableDefinition>() != null) {
    return Icons.touch_app_outlined;
  }
  return Icons.view_in_ar_outlined;
}

IconData _paletteIcon(ForgePaletteItemKind kind) => switch (kind) {
  ForgePaletteItemKind.floorTile => Icons.grid_view_outlined,
  ForgePaletteItemKind.propCube => Icons.widgets_outlined,
  ForgePaletteItemKind.solidBlock => Icons.view_in_ar_outlined,
  ForgePaletteItemKind.relayConsole => Icons.touch_app_outlined,
  ForgePaletteItemKind.objectiveSwitch => Icons.task_alt_outlined,
  ForgePaletteItemKind.objectiveGate => Icons.door_sliding_outlined,
  ForgePaletteItemKind.guardian => Icons.shield_outlined,
  ForgePaletteItemKind.collectibleItem => Icons.diamond_outlined,
  ForgePaletteItemKind.turnInConsole => Icons.flag_outlined,
};

String _paletteCategoryLabel(ForgePaletteItemCategory category) =>
    switch (category) {
      ForgePaletteItemCategory.world => 'WORLD OBJECTS',
      ForgePaletteItemCategory.gameplay => 'GAMEPLAY RULES',
    };

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
