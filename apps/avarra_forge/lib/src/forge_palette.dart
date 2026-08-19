import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';

enum ForgePaletteItemCategory { world, gameplay }

enum ForgePaletteItemKind {
  floorTile,
  propCube,
  solidBlock,
  relayConsole,
  objectiveSwitch,
  objectiveGate,
}

enum ForgeBrushMode { none, paintFloor, eraseFloor }

final class ForgePaletteItem {
  const ForgePaletteItem({
    required this.id,
    required this.label,
    required this.description,
    required this.kind,
  });

  final String id;
  final String label;
  final String description;
  final ForgePaletteItemKind kind;

  ForgePaletteItemCategory get category => switch (kind) {
    ForgePaletteItemKind.floorTile ||
    ForgePaletteItemKind.propCube ||
    ForgePaletteItemKind.solidBlock ||
    ForgePaletteItemKind.relayConsole => ForgePaletteItemCategory.world,
    ForgePaletteItemKind.objectiveSwitch ||
    ForgePaletteItemKind.objectiveGate => ForgePaletteItemCategory.gameplay,
  };

  double get placementGridSize => kind == ForgePaletteItemKind.floorTile
      ? forgeFloorTileSize
      : forgePlacementGridSize;

  WorldEntityDefinition createEntity({
    required EntityId entityId,
    required AssetId assetId,
    required ContentVector3 groundPosition,
    double? gridSize,
  }) {
    final effectiveGridSize = gridSize ?? placementGridSize;
    final x = snapForgePlacement(groundPosition.x, gridSize: effectiveGridSize);
    final z = snapForgePlacement(groundPosition.z, gridSize: effectiveGridSize);
    final components = switch (kind) {
      ForgePaletteItemKind.floorTile => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, -0.125, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: const ContentVector3(2, 0.25, 2),
        ),
        RenderableReferenceDefinition(assetId: assetId),
        const PhysicsColliderDefinition(
          halfExtents: ContentVector3(1, 0.125, 1),
          bodyKind: ContentPhysicsBodyKind.staticBody,
          isSensor: false,
        ),
      ],
      ForgePaletteItemKind.propCube => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, 0.5, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: const ContentVector3(0.8, 1, 0.8),
        ),
        RenderableReferenceDefinition(assetId: assetId),
      ],
      ForgePaletteItemKind.solidBlock => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, 0.5, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: const ContentVector3(1, 1, 1),
        ),
        RenderableReferenceDefinition(assetId: assetId),
        const PhysicsColliderDefinition(
          halfExtents: ContentVector3(0.5, 0.5, 0.5),
          bodyKind: ContentPhysicsBodyKind.staticBody,
          isSensor: false,
        ),
      ],
      ForgePaletteItemKind.relayConsole => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, 0.5, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: const ContentVector3(0.8, 1, 0.8),
        ),
        RenderableReferenceDefinition(assetId: assetId),
        const PhysicsColliderDefinition(
          halfExtents: ContentVector3(0.4, 0.5, 0.4),
          bodyKind: ContentPhysicsBodyKind.staticBody,
          isSensor: false,
        ),
        const InteractableDefinition(label: 'Relay console', range: 2.2),
        const SetPersistentFlagOnInteractDefinition(
          flagKey: 'activated',
          value: true,
        ),
        PersistentFlagsDefinition(const {'activated': false}),
      ],
      ForgePaletteItemKind.objectiveSwitch => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, 0.5, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: const ContentVector3(0.8, 1, 0.8),
        ),
        RenderableReferenceDefinition(assetId: assetId),
        const PhysicsColliderDefinition(
          halfExtents: ContentVector3(0.4, 0.5, 0.4),
          bodyKind: ContentPhysicsBodyKind.staticBody,
          isSensor: false,
        ),
        const InteractableDefinition(
          label: 'Activate primary relay',
          range: 2.2,
        ),
        const SetPersistentFlagOnInteractDefinition(
          flagKey: 'activated',
          value: true,
        ),
        PersistentFlagsDefinition(const {'activated': false}),
        const ObjectiveDefinition(group: forgeDefaultObjectiveGroup),
      ],
      ForgePaletteItemKind.objectiveGate => <ContentComponentDefinition>[
        TransformDefinition(
          position: ContentVector3(x, 1, z),
          rotation: const ContentQuaternion(0, 0, 0, 1),
          scale: const ContentVector3(1, 2, 3),
        ),
        RenderableReferenceDefinition(assetId: assetId),
        const PhysicsColliderDefinition(
          halfExtents: ContentVector3(0.5, 1, 1.5),
          bodyKind: ContentPhysicsBodyKind.staticBody,
          isSensor: false,
        ),
        const ObjectiveGateDefinition(
          label: 'Primary gate',
          group: forgeDefaultObjectiveGroup,
          requiredCount: 1,
        ),
      ],
    };
    return WorldEntityDefinition(id: entityId, components: components);
  }
}

const double forgePlacementGridSize = 0.5;
const double forgeFloorTileSize = 2;
const String forgeDefaultObjectiveGroup = 'primary';

const forgeObjectPalette = <ForgePaletteItem>[
  ForgePaletteItem(
    id: 'floor_tile',
    label: 'Floor tile',
    description: 'Walkable 2 x 2 foundation',
    kind: ForgePaletteItemKind.floorTile,
  ),
  ForgePaletteItem(
    id: 'prop_cube',
    label: 'Prop cube',
    description: 'Visual decoration without collision',
    kind: ForgePaletteItemKind.propCube,
  ),
  ForgePaletteItem(
    id: 'solid_block',
    label: 'Solid block',
    description: 'Static obstacle with collision',
    kind: ForgePaletteItemKind.solidBlock,
  ),
  ForgePaletteItem(
    id: 'relay_console',
    label: 'Relay console',
    description: 'Persistent interactive objective prop',
    kind: ForgePaletteItemKind.relayConsole,
  ),
  ForgePaletteItem(
    id: 'objective_switch',
    label: 'Objective switch',
    description: 'Persistent objective in the primary group',
    kind: ForgePaletteItemKind.objectiveSwitch,
  ),
  ForgePaletteItem(
    id: 'objective_gate',
    label: 'Objective gate',
    description: 'Opens after one primary objective',
    kind: ForgePaletteItemKind.objectiveGate,
  ),
];

double snapForgePlacement(
  double value, {
  double gridSize = forgePlacementGridSize,
}) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'Must be finite.');
  }
  if (!gridSize.isFinite || gridSize <= 0) {
    throw ArgumentError.value(gridSize, 'gridSize', 'Must be finite and > 0.');
  }
  final snapped = (value / gridSize).roundToDouble() * gridSize;
  return snapped == 0 ? 0 : snapped;
}

final class ForgeFloorCell {
  const ForgeFloorCell(this.x, this.z);

  factory ForgeFloorCell.fromGround(ContentVector3 position) {
    return ForgeFloorCell(
      (position.x / forgeFloorTileSize).round(),
      (position.z / forgeFloorTileSize).round(),
    );
  }

  final int x;
  final int z;

  ContentVector3 get groundPosition =>
      ContentVector3(x * forgeFloorTileSize, 0, z * forgeFloorTileSize);

  @override
  bool operator ==(Object other) {
    return other is ForgeFloorCell && other.x == x && other.z == z;
  }

  @override
  int get hashCode => Object.hash(x, z);

  @override
  String toString() => '$x,$z';
}

List<ForgeFloorCell> forgeFloorStrokeCells(
  ForgeFloorCell start,
  ForgeFloorCell end,
) {
  final cells = <ForgeFloorCell>[];
  var x = start.x;
  var z = start.z;
  final deltaX = (end.x - start.x).abs();
  final stepX = start.x < end.x ? 1 : -1;
  final deltaZ = (end.z - start.z).abs();
  final stepZ = start.z < end.z ? 1 : -1;
  var error = deltaX - deltaZ;

  while (true) {
    cells.add(ForgeFloorCell(x, z));
    if (x == end.x && z == end.z) break;
    final doubledError = 2 * error;
    if (doubledError > -deltaZ) {
      error -= deltaZ;
      x += stepX;
    }
    if (doubledError < deltaX) {
      error += deltaX;
      z += stepZ;
    }
  }
  return List.unmodifiable(cells);
}

bool isForgeFloorTile(WorldEntityDefinition entity) {
  final transform = entity.component<TransformDefinition>();
  final collider = entity.component<PhysicsColliderDefinition>();
  return transform != null &&
      collider != null &&
      transform.position.y == -0.125 &&
      transform.scale == const ContentVector3(2, 0.25, 2) &&
      collider.halfExtents == const ContentVector3(1, 0.125, 1) &&
      collider.bodyKind == ContentPhysicsBodyKind.staticBody &&
      !collider.isSensor;
}
