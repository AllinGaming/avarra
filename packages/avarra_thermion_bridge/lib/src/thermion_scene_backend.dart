import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_scene_bridge/avarra_scene_bridge.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide EntityId;

import 'thermion_asset_uri_resolver.dart';
import 'thermion_entity_index.dart';

/// Mutable backend handle owned exclusively by [SceneBridge].
final class ThermionSceneObject {
  ThermionSceneObject({
    required this.entityId,
    required this.assetId,
    required this.asset,
    required this.thermionEntities,
    this.opacity = 1,
    this.selected = false,
  });

  final EntityId entityId;
  AssetId assetId;
  ThermionAsset<dynamic> asset;
  Set<ThermionEntity> thermionEntities;
  double opacity;
  bool selected;
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
  final ThermionEntityIndex _entityIndex = ThermionEntityIndex();
  final Map<EntityId, ThermionSceneObject> _objectsByEntityId = {};

  EntityId? entityIdForThermionEntity(ThermionEntity thermionEntity) {
    return _entityIndex.lookup(thermionEntity);
  }

  ThermionSceneObject? objectForEntity(EntityId entityId) {
    return _objectsByEntityId[entityId];
  }

  /// Applies cosmetic transparency to an asset authored for alpha blending.
  ///
  /// AVARRA's first occluder proof uses white `baseColorFactor` values and a
  /// glTF `BLEND` material. Richer material overrides remain renderer work.
  Future<void> setEntityOpacity(EntityId entityId, double opacity) async {
    if (!opacity.isFinite || opacity < 0 || opacity > 1) {
      throw ArgumentError.value(
        opacity,
        'opacity',
        'Must be from zero to one.',
      );
    }
    final object = _objectsByEntityId[entityId];
    if (object == null || object.opacity == opacity) {
      return;
    }
    await _applyMaterialState(object, opacity: opacity);
  }

  /// Applies a renderer-local selection tint without changing stable identity.
  Future<void> setEntitySelected(EntityId entityId, bool selected) async {
    final object = _objectsByEntityId[entityId];
    if (object == null || object.selected == selected) {
      return;
    }
    await _applyMaterialState(object, selected: selected);
  }

  @override
  Future<ThermionSceneObject> create(PresentationEntity entity) async {
    final object = await _load(entity);
    try {
      _register(object);
      return object;
    } on Object {
      await _viewer.destroyAsset(object.asset);
      rethrow;
    }
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
    final opacity = handle.opacity;
    final selected = handle.selected;
    try {
      await _viewer.destroyAsset(handle.asset);
    } on Object {
      await _viewer.destroyAsset(replacement.asset);
      rethrow;
    }
    _unregister(handle);
    handle
      ..assetId = entity.renderAssetId
      ..asset = replacement.asset
      ..thermionEntities = replacement.thermionEntities
      ..opacity = 1
      ..selected = false;
    _register(handle);
    if (opacity != 1 || selected) {
      await _applyMaterialState(handle, opacity: opacity, selected: selected);
    }
  }

  @override
  Future<void> destroy(ThermionSceneObject handle) async {
    await _viewer.destroyAsset(handle.asset);
    _unregister(handle);
  }

  Future<ThermionSceneObject> _load(PresentationEntity entity) async {
    final assetUri = _assetUriResolver.resolve(entity.renderAssetId);
    final asset = await _viewer.loadGltf(assetUri);
    try {
      await asset.setCastShadows(true);
      await asset.setReceiveShadows(true);
      await asset.setTransform(
        presentationTransformToThermionMatrix(entity.transform),
      );
      final thermionEntities = {
        asset.entity,
        ...await asset.getChildEntities(),
      };
      return ThermionSceneObject(
        entityId: entity.entityId,
        assetId: entity.renderAssetId,
        asset: asset,
        thermionEntities: thermionEntities,
      );
    } on Object {
      await _viewer.destroyAsset(asset);
      rethrow;
    }
  }

  void _register(ThermionSceneObject object) {
    _entityIndex.bind(object.entityId, object.thermionEntities);
    _objectsByEntityId[object.entityId] = object;
  }

  void _unregister(ThermionSceneObject object) {
    _entityIndex.unbind(object.entityId);
    _objectsByEntityId.remove(object.entityId);
  }

  Future<void> _applyMaterialState(
    ThermionSceneObject object, {
    double? opacity,
    bool? selected,
  }) async {
    final nextOpacity = opacity ?? object.opacity;
    final nextSelected = selected ?? object.selected;
    final red = nextSelected ? 0.44 : 1.0;
    final green = nextSelected ? 0.72 : 1.0;
    final blue = nextSelected ? 0.65 : 1.0;
    final materialInstances = await object.asset.getMaterialInstancesAsMap();
    for (final instances in materialInstances.values) {
      for (final instance in instances) {
        await instance.setParameterFloat4(
          'baseColorFactor',
          red,
          green,
          blue,
          nextOpacity,
        );
      }
    }
    object
      ..opacity = nextOpacity
      ..selected = nextSelected;
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
