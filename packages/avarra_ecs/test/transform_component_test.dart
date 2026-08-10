import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('defaults to an identity local transform', () {
    final transform = TransformComponent();

    expect(transform.position, Vector3.zero());
    expect(transform.rotation, Quaternion.identity());
    expect(transform.scale, Vector3.all(1));
  });

  test('copies input and copyWith values to avoid accidental aliasing', () {
    final input = Vector3(1, 2, 3);
    final transform = TransformComponent(position: input);
    input.x = 99;

    final copy = transform.copyWith();
    copy.position.x = 7;

    expect(transform.position, Vector3(1, 2, 3));
    expect(copy.position, Vector3(7, 2, 3));
  });

  test('participates in typed ECS queries', () {
    final world = EcsWorld();
    final handle = world.createEntity();
    world.addComponent(handle, TransformComponent(position: Vector3(5, 0, -2)));

    final result = world.query<TransformComponent>().single;

    expect(result.handle, handle);
    expect(result.component.position, Vector3(5, 0, -2));
  });
}
