import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_scene_bridge/avarra_scene_bridge.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide EntityId;

import 'thermion_animation_request.dart';
import 'thermion_asset_uri_resolver.dart';
import 'thermion_entity_index.dart';

/// Mutable backend handle owned exclusively by [SceneBridge].
final class ThermionSceneObject {
  ThermionSceneObject({
    required this.entityId,
    required this.assetId,
    required this.asset,
    required this.thermionEntities,
    required this.animationNames,
    this.opacity = 1,
    this.selected = false,
    this.hitFlash = 0,
  });

  final EntityId entityId;
  AssetId assetId;
  ThermionAsset<dynamic> asset;
  Set<ThermionEntity> thermionEntities;
  Set<String> animationNames;
  bool animationComponentAttached = false;
  ThermionAnimationRequest? activeAnimation;
  double opacity;
  bool selected;
  double hitFlash;
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
  final Map<AssetId, _ThermionAssetSource> _assetSources = {};

  EntityId? entityIdForThermionEntity(ThermionEntity thermionEntity) {
    return _entityIndex.lookup(thermionEntity);
  }

  ThermionSceneObject? objectForEntity(EntityId entityId) {
    return _objectsByEntityId[entityId];
  }

  /// Starts or replaces a renderer-local glTF clip for one stable entity.
  ///
  /// Returns false when the entity or requested clip is unavailable, allowing
  /// creator-selected custom models without animation data to remain playable.
  Future<bool> setEntityAnimation(
    EntityId entityId,
    ThermionAnimationRequest? request,
  ) async {
    final object = _objectsByEntityId[entityId];
    if (object == null) {
      return false;
    }
    final active = object.activeAnimation;
    if (request == null) {
      if (active != null) {
        await object.asset.stopGltfAnimationByName(active.clipName);
        object.activeAnimation = null;
      }
      return true;
    }
    if (!object.animationNames.contains(request.clipName)) {
      return false;
    }
    if (active == request) {
      return true;
    }
    if (!object.animationComponentAttached) {
      await object.asset.addAnimationComponent();
      object.animationComponentAttached = true;
    }
    await object.asset.playGltfAnimationByName(
      request.clipName,
      loop: request.loop,
      replaceActive: true,
      crossfade: request.crossfadeSeconds,
      speed: request.speed,
    );
    object.activeAnimation = request;
    return true;
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

  /// Applies a short renderer-local hit flash without changing simulation.
  Future<void> setEntityHitFlash(EntityId entityId, double intensity) async {
    if (!intensity.isFinite || intensity < 0 || intensity > 1) {
      throw ArgumentError.value(
        intensity,
        'intensity',
        'Must be from zero to one.',
      );
    }
    final object = _objectsByEntityId[entityId];
    if (object == null || object.hitFlash == intensity) {
      return;
    }
    await _applyMaterialState(object, hitFlash: intensity);
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
    final hitFlash = handle.hitFlash;
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
      ..animationNames = replacement.animationNames
      ..animationComponentAttached = false
      ..activeAnimation = null
      ..opacity = 1
      ..selected = false
      ..hitFlash = 0;
    _register(handle);
    if (opacity != 1 || selected || hitFlash != 0) {
      await _applyMaterialState(
        handle,
        opacity: opacity,
        selected: selected,
        hitFlash: hitFlash,
      );
    }
  }

  @override
  Future<void> destroy(ThermionSceneObject handle) async {
    await _viewer.destroyAsset(handle.asset);
    _unregister(handle);
  }

  Future<ThermionSceneObject> _load(PresentationEntity entity) async {
    final source = await _sourceFor(entity.renderAssetId);
    final asset = await source.createInstance();
    try {
      await _viewer.addToScene(asset);
      await _enableRenderableShadows(asset);
      await asset.setTransform(
        presentationTransformToThermionMatrix(entity.transform),
      );
      final thermionEntities = {
        asset.entity,
        ...await asset.getChildEntities(),
      };
      final animationNames = Set.unmodifiable(
        await asset.getGltfAnimationNames(),
      );
      return ThermionSceneObject(
        entityId: entity.entityId,
        assetId: entity.renderAssetId,
        asset: asset,
        thermionEntities: thermionEntities,
        animationNames: animationNames,
      );
    } on Object {
      await _viewer.destroyAsset(asset);
      rethrow;
    }
  }

  Future<void> _enableRenderableShadows(ThermionAsset<dynamic> asset) async {
    final app = FilamentApp.instance;
    if (app == null) return;
    final renderableManager = app.renderableManager;
    final renderableEntities = (await asset.getMaterialInstancesAsMap()).keys;
    for (final entity in renderableEntities) {
      await renderableManager.setCastShadows(entity, true);
      await renderableManager.setReceiveShadows(entity, true);
    }
  }

  Future<_ThermionAssetSource> _sourceFor(AssetId assetId) async {
    final cached = _assetSources[assetId];
    if (cached != null) {
      return cached;
    }
    final assetUri = _assetUriResolver.resolve(assetId);
    final owner = await _viewer.loadGltf(
      assetUri,
      addToScene: false,
      releaseSourceData: false,
    );
    final source = _ThermionAssetSource(owner);
    _assetSources[assetId] = source;
    return source;
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
    double? hitFlash,
  }) async {
    final nextOpacity = opacity ?? object.opacity;
    final nextSelected = selected ?? object.selected;
    final nextHitFlash = hitFlash ?? object.hitFlash;
    final baseRed = nextSelected ? 0.44 : 1.0;
    final baseGreen = nextSelected ? 0.72 : 1.0;
    final baseBlue = nextSelected ? 0.65 : 1.0;
    final red = baseRed + ((1 - baseRed) * nextHitFlash);
    final green = baseGreen * (1 - 0.72 * nextHitFlash);
    final blue = baseBlue * (1 - 0.82 * nextHitFlash);
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
      ..selected = nextSelected
      ..hitFlash = nextHitFlash;
  }
}

final class _ThermionAssetSource {
  _ThermionAssetSource(this.owner);

  final ThermionAsset<dynamic> owner;
  bool _initialInstanceAvailable = true;

  Future<ThermionAsset<dynamic>> createInstance() async {
    if (_initialInstanceAvailable) {
      _initialInstanceAvailable = false;
      return owner.getInstance(0);
    }
    return owner.createInstance();
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
