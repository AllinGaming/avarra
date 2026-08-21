import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/gameplay_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds cosmetic motion without mutating canonical transforms', () {
    final characterId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000601');
    final collectibleId = EntityId.parse(
      '01890f47-e8b8-7a68-8000-000000000602',
    );
    final snapshot = PresentationSnapshot([
      _entity(characterId, y: 0.4),
      _entity(collectibleId, y: 0.7),
    ]);

    final animated = applyGameplayMotion(
      snapshot: snapshot,
      motionKinds: {
        characterId: GameplayMotionKind.character,
        collectibleId: GameplayMotionKind.collectible,
      },
      elapsed: const Duration(milliseconds: 750),
      activeCharacterEntityIds: {characterId},
    );

    expect(snapshot.entities[0].transform.position.y, 0.4);
    expect(snapshot.entities[1].transform.position.y, 0.7);
    expect(
      animated.entities[0].transform,
      isNot(snapshot.entities[0].transform),
    );
    expect(
      animated.entities[1].transform,
      isNot(snapshot.entities[1].transform),
    );
    expect(
      animated.entities[1].transform.rotation,
      isNot(snapshot.entities[1].transform.rotation),
    );
    expect(
      animated.entities[0].transform.rotation,
      isNot(snapshot.entities[0].transform.rotation),
    );
  });

  test('bounds animated work while retaining priority entities', () {
    final firstId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000611');
    final secondId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000612');
    final priorityId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000613');
    final snapshot = PresentationSnapshot([
      _entity(firstId),
      _entity(secondId),
      _entity(priorityId),
    ]);

    final animated = applyGameplayMotion(
      snapshot: snapshot,
      motionKinds: {
        firstId: GameplayMotionKind.interactable,
        secondId: GameplayMotionKind.interactable,
        priorityId: GameplayMotionKind.character,
      },
      elapsed: const Duration(milliseconds: 420),
      priorityEntityIds: {priorityId},
      maximumAnimatedEntities: 1,
    );
    final baseById = {
      for (final entity in snapshot.entities) entity.entityId: entity,
    };
    final animatedById = {
      for (final entity in animated.entities) entity.entityId: entity,
    };

    expect(identical(animatedById[firstId], baseById[firstId]), isTrue);
    expect(identical(animatedById[secondId], baseById[secondId]), isTrue);
    expect(identical(animatedById[priorityId], baseById[priorityId]), isFalse);
  });
}

PresentationEntity _entity(EntityId entityId, {double y = 0}) {
  return PresentationEntity(
    entityId: entityId,
    renderAssetId: AssetId.parse('01890f47-e8b8-7a68-8000-000000000699'),
    transform: PresentationTransform(
      position: PresentationVector3(1, y, 2),
      rotation: const PresentationQuaternion(0, 0, 0, 1),
      scale: const PresentationVector3(1, 1, 1),
    ),
  );
}
