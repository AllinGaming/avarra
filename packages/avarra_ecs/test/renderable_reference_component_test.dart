import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:test/test.dart';

void main() {
  test('stores only a stable asset reference', () {
    final assetId = AssetId.parse('01890f47-e8b8-7a68-8000-000000000001');
    final component = RenderableReferenceComponent(assetId: assetId);

    expect(component.assetId, same(assetId));
  });
}
