import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_forge/src/forge_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('snaps placement coordinates to the half-unit authoring grid', () {
    expect(snapForgePlacement(1.24), 1);
    expect(snapForgePlacement(1.26), 1.5);
    expect(snapForgePlacement(-1.26), -1.5);
    expect(snapForgePlacement(-0.24), 0);
  });

  test('palette presets create typed gameplay-ready entities', () {
    final assetId = AssetId.parse('01890f47-e8b8-7a68-8000-000000000502');
    final items = {for (final item in forgeObjectPalette) item.kind: item};

    final solid = items[ForgePaletteItemKind.solidBlock]!.createEntity(
      entityId: EntityId.generate(),
      assetId: assetId,
      groundPosition: const ContentVector3(1.24, 0, -1.26),
    );
    expect(
      solid.component<TransformDefinition>()!.position,
      const ContentVector3(1, 0.5, -1.5),
    );
    expect(
      solid.component<PhysicsColliderDefinition>()!.bodyKind,
      ContentPhysicsBodyKind.staticBody,
    );

    final prop = items[ForgePaletteItemKind.propCube]!.createEntity(
      entityId: EntityId.generate(),
      assetId: assetId,
      groundPosition: const ContentVector3(0, 0, 0),
    );
    expect(prop.component<RenderableReferenceDefinition>()!.assetId, assetId);
    expect(prop.component<PhysicsColliderDefinition>(), isNull);

    final console = items[ForgePaletteItemKind.relayConsole]!.createEntity(
      entityId: EntityId.generate(),
      assetId: assetId,
      groundPosition: const ContentVector3(0, 0, 0),
    );
    expect(console.component<InteractableDefinition>()!.label, 'Relay console');
    expect(console.component<PersistentFlagsDefinition>()!.flags, const {
      'activated': false,
    });

    final objectiveSwitch = items[ForgePaletteItemKind.objectiveSwitch]!
        .createEntity(
          entityId: EntityId.generate(),
          assetId: assetId,
          groundPosition: const ContentVector3(0, 0, 0),
        );
    expect(
      objectiveSwitch.component<ObjectiveDefinition>()!.group,
      forgeDefaultObjectiveGroup,
    );
    expect(
      objectiveSwitch
          .component<SetPersistentFlagOnInteractDefinition>()!
          .flagKey,
      'activated',
    );

    final objectiveGate = items[ForgePaletteItemKind.objectiveGate]!
        .createEntity(
          entityId: EntityId.generate(),
          assetId: assetId,
          groundPosition: const ContentVector3(0, 0, 0),
        );
    final gate = objectiveGate.component<ObjectiveGateDefinition>()!;
    expect(gate.group, forgeDefaultObjectiveGroup);
    expect(gate.requiredCount, 1);
    expect(
      objectiveGate.component<PhysicsColliderDefinition>()!.bodyKind,
      ContentPhysicsBodyKind.staticBody,
    );

    final floor = items[ForgePaletteItemKind.floorTile]!.createEntity(
      entityId: EntityId.generate(),
      assetId: assetId,
      groundPosition: const ContentVector3(1.2, 0, 0),
    );
    expect(
      floor.component<TransformDefinition>()!.scale,
      const ContentVector3(2, 0.25, 2),
    );
    expect(
      floor.component<TransformDefinition>()!.position.x,
      forgeFloorTileSize,
    );
    expect(isForgeFloorTile(floor), isTrue);
    expect(isForgeFloorTile(solid), isFalse);
  });

  test('floor brush fills every deterministic cell along a stroke', () {
    final start = ForgeFloorCell.fromGround(const ContentVector3(0.2, 0, -0.2));
    final end = ForgeFloorCell.fromGround(const ContentVector3(6.2, 0, 2.2));

    expect(start, const ForgeFloorCell(0, 0));
    expect(end, const ForgeFloorCell(3, 1));
    expect(forgeFloorStrokeCells(start, end), const [
      ForgeFloorCell(0, 0),
      ForgeFloorCell(1, 0),
      ForgeFloorCell(2, 1),
      ForgeFloorCell(3, 1),
    ]);
  });
}
