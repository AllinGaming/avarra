import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:flutter/services.dart';

/// Loads a creator-exported desktop file when configured, otherwise an asset.
Future<String> loadWorldPackageSource({
  required String configuredFilePath,
  required String bundledAssetPath,
  AssetBundle? assetBundle,
}) {
  if (configuredFilePath.isNotEmpty) {
    return File(configuredFilePath).readAsString();
  }
  return (assetBundle ?? rootBundle).loadString(bundledAssetPath);
}

/// Gives every imported world its own stable save slot.
SaveId saveIdForWorldPackageSource({
  required String configuredFilePath,
  required WorldId worldId,
  required SaveId bundledSaveId,
  bool isRuntimeImport = false,
}) {
  return configuredFilePath.isEmpty && !isRuntimeImport
      ? bundledSaveId
      : SaveId.parse(worldId.value);
}
