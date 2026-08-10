import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('PresentationExtractor', () {
    test('extracts only entities with transform and render asset', () {
      final world = EcsWorld();
      final renderable = world.createEntity(
        entityId: EntityId.parse('01890f47-e8b8-7a68-8000-000000000002'),
      );
      world
        ..addComponent(
          renderable,
          TransformComponent(position: Vector3(4, 5, 6)),
        )
        ..addComponent(
          renderable,
          RenderableReferenceComponent(
            assetId: AssetId.parse('01890f47-e8b8-7a68-8000-000000000003'),
          ),
        );

      final transformOnly = world.createEntity(
        entityId: EntityId.parse('01890f47-e8b8-7a68-8000-000000000001'),
      );
      world.addComponent(transformOnly, TransformComponent());

      final snapshot = const PresentationExtractor().extract(world);

      expect(snapshot.length, 1);
      expect(snapshot.entities.single.entityId, world.entityIdOf(renderable));
      expect(
        snapshot.entities.single.transform.position,
        const PresentationVector3(4, 5, 6),
      );
    });

    test('copies mutable transform values', () {
      final world = EcsWorld();
      final handle = world.createEntity();
      final transform = TransformComponent(position: Vector3(1, 2, 3));
      world
        ..addComponent(handle, transform)
        ..addComponent(
          handle,
          RenderableReferenceComponent(assetId: AssetId.generate()),
        );

      final snapshot = const PresentationExtractor().extract(world);
      transform.position.setValues(9, 9, 9);

      expect(
        snapshot.entities.single.transform.position,
        const PresentationVector3(1, 2, 3),
      );
    });

    test('sorts entities by stable ID', () {
      final world = EcsWorld();
      final later = world.createEntity(
        entityId: EntityId.parse('01890f47-e8b8-7a68-8000-000000000002'),
      );
      final earlier = world.createEntity(
        entityId: EntityId.parse('01890f47-e8b8-7a68-8000-000000000001'),
      );
      for (final handle in [later, earlier]) {
        world
          ..addComponent(handle, TransformComponent())
          ..addComponent(
            handle,
            RenderableReferenceComponent(assetId: AssetId.generate()),
          );
      }

      final snapshot = const PresentationExtractor().extract(world);

      expect(snapshot.entities.first.entityId, world.entityIdOf(earlier));
      expect(snapshot.entities.last.entityId, world.entityIdOf(later));
    });
  });

  test('presentation snapshots reject duplicate entity IDs', () {
    final entityId = EntityId.generate();
    final entity = PresentationEntity(
      entityId: entityId,
      renderAssetId: AssetId.generate(),
      transform: const PresentationTransform(
        position: PresentationVector3(0, 0, 0),
        rotation: PresentationQuaternion(0, 0, 0, 1),
        scale: PresentationVector3(1, 1, 1),
      ),
    );

    expect(
      () => PresentationSnapshot([entity, entity]),
      throwsA(
        isA<AvarraException>().having(
          (error) => error.code,
          'code',
          ClientErrorCodes.duplicatePresentationEntity,
        ),
      ),
    );
  });
}
