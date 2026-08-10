import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_scene_bridge/avarra_scene_bridge.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

import 'thermion_asset_uri_resolver.dart';

/// Mutable backend handle owned exclusively by [SceneBridge].
final class ThermionSceneObject {
  ThermionSceneObject({required this.assetId, required this.asset});

  AssetId assetId;
  ThermionAsset<dynamic> asset;
}

/// Adapts renderer-neutral AVARRA presentation entities to Thermion assets.
final class ThermionSceneBackend implements SceneBackend<ThermionSceneObject> {
  factory ThermionSceneBackend({
    required ThermionViewer viewer,
    required ThermionAssetUriResolver assetUriResolver,
  }) {
    return ThermionSceneBackend._(viewer, assetUriResolver);
  }

  ThermionSceneBackend._(this._viewer, this._assetUriResolver);

  final ThermionViewer _viewer;
  final ThermionAssetUriResolver _assetUriResolver;

  @override
  Future<ThermionSceneObject> create(PresentationEntity entity) async {
    final asset = await _load(entity);
    return ThermionSceneObject(assetId: entity.renderAssetId, asset: asset);
  }

  @override
  Future<void> update(
    ThermionSceneObject handle,
    PresentationEntity entity,
  ) async {
    if (handle.assetId == entity.renderAssetId) {
      await handle.asset.setTransform(
        presentationTransformToThermionMatrix(entity.transform),
      );
      return;
    }

    final replacement = await _load(entity);
    try {
      await _viewer.destroyAsset(handle.asset);
    } on Object {
      await _viewer.destroyAsset(replacement);
      rethrow;
    }
    handle
      ..assetId = entity.renderAssetId
      ..asset = replacement;
  }

  @override
  Future<void> destroy(ThermionSceneObject handle) async {
    await _viewer.destroyAsset(handle.asset);
  }

  Future<ThermionAsset<dynamic>> _load(PresentationEntity entity) async {
    final assetUri = _assetUriResolver.resolve(entity.renderAssetId);
    final asset = await _viewer.loadGltf(assetUri);
    try {
      await asset.setCastShadows(true);
      await asset.setReceiveShadows(true);
      await asset.setTransform(
        presentationTransformToThermionMatrix(entity.transform),
      );
      return asset;
    } on Object {
      await _viewer.destroyAsset(asset);
      rethrow;
    }
  }
}

/// Converts AVARRA's copied transform values to Thermion's matrix convention.
Matrix4 presentationTransformToThermionMatrix(PresentationTransform transform) {
  return Matrix4.compose(
    Vector3(transform.position.x, transform.position.y, transform.position.z),
    Quaternion(
      transform.rotation.x,
      transform.rotation.y,
      transform.rotation.z,
      transform.rotation.w,
    ),
    Vector3(transform.scale.x, transform.scale.y, transform.scale.z),
  );
}
