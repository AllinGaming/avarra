import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_isometric/avarra_isometric.dart';
import 'package:avarra_thermion_bridge/avarra_thermion_bridge.dart';
import 'package:avarra_thermion_bridge/src/thermion_entity_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('asset registry resolves canonical asset IDs', () {
    final assetId = AssetId.parse('01890f47-e8b8-7a68-9000-000000000001');
    final resolver = MapThermionAssetUriResolver({
      assetId: 'asset://assets/models/cube.glb',
    });

    expect(resolver.resolve(assetId), 'asset://assets/models/cube.glb');
  });

  test('asset registry reports a stable missing-asset error', () {
    final resolver = MapThermionAssetUriResolver(const {});

    expect(
      () => resolver.resolve(AssetId.generate()),
      throwsA(
        isA<AvarraException>().having(
          (error) => error.code,
          'code',
          ThermionErrorCodes.assetUriNotFound,
        ),
      ),
    );
  });

  test('animation requests compare by clip playback policy', () {
    const idle = ThermionAnimationRequest(clipName: 'Idle');
    const sameIdle = ThermionAnimationRequest(clipName: 'Idle');
    const oneShotIdle = ThermionAnimationRequest(clipName: 'Idle', loop: false);

    expect(idle, sameIdle);
    expect(idle.hashCode, sameIdle.hashCode);
    expect(idle, isNot(oneShotIdle));
  });

  test('viewport rejects out-of-range hit flash intensity', () {
    final entityId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000001');

    expect(
      () => AvarraThermionViewport(
        snapshot: PresentationSnapshot.empty,
        assetUriResolver: MapThermionAssetUriResolver(const {}),
        cameraRig: IsometricCameraRig(),
        hitFlashIntensities: {entityId: 1.01},
      ),
      throwsArgumentError,
    );
  });

  test('presentation transform converts to a decomposable Thermion matrix', () {
    final matrix = presentationTransformToThermionMatrix(
      const PresentationTransform(
        position: PresentationVector3(2, 3, 4),
        rotation: PresentationQuaternion(0, 0, 0, 1),
        scale: PresentationVector3(5, 6, 7),
      ),
    );
    final translation = Vector3.zero();
    final rotation = Quaternion.identity();
    final scale = Vector3.zero();

    matrix.decompose(translation, rotation, scale);

    expect(translation, closeToVector3(Vector3(2, 3, 4)));
    expect(scale, closeToVector3(Vector3(5, 6, 7)));
    expect(rotation.x, closeTo(0, 0.000001));
    expect(rotation.y, closeTo(0, 0.000001));
    expect(rotation.z, closeTo(0, 0.000001));
    expect(rotation.w, closeTo(1, 0.000001));
  });

  test('Thermion entity index preserves stable selection identity', () {
    final firstId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000001');
    final secondId = EntityId.parse('01890f47-e8b8-7a68-8000-000000000002');
    final index = ThermionEntityIndex()..bind(firstId, [10, 11, 12]);

    expect(index.lookup(10), firstId);
    expect(index.lookup(12), firstId);
    expect(index.lookup(99), isNull);
    expect(() => index.bind(secondId, [12]), throwsStateError);

    index
      ..unbind(firstId)
      ..bind(secondId, [12]);
    expect(index.lookup(10), isNull);
    expect(index.lookup(12), secondId);
  });
}

Matcher closeToVector3(Vector3 expected) {
  return predicate<Vector3>(
    (actual) =>
        (actual.x - expected.x).abs() < 0.000001 &&
        (actual.y - expected.y).abs() < 0.000001 &&
        (actual.z - expected.z).abs() < 0.000001,
    'is within 0.000001 of $expected',
  );
}
