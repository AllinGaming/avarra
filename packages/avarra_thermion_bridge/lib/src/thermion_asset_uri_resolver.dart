import 'package:avarra_core/avarra_core.dart';

import 'thermion_error_codes.dart';

/// Resolves canonical AVARRA asset IDs to URIs understood by Thermion.
abstract interface class ThermionAssetUriResolver {
  String resolve(AssetId assetId);
}

/// Immutable asset URI registry for the initial static-scene slice.
final class MapThermionAssetUriResolver implements ThermionAssetUriResolver {
  factory MapThermionAssetUriResolver(Map<AssetId, String> assetUris) {
    return MapThermionAssetUriResolver._(Map.unmodifiable(assetUris));
  }

  MapThermionAssetUriResolver._(this._assetUris);

  final Map<AssetId, String> _assetUris;

  @override
  String resolve(AssetId assetId) {
    final assetUri = _assetUris[assetId];
    if (assetUri == null) {
      throw AvarraException(
        code: ThermionErrorCodes.assetUriNotFound,
        message: 'No Thermion asset URI is registered for this asset ID.',
        context: {'assetId': assetId.value},
      );
    }
    return assetUri;
  }
}
