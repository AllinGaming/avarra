import 'package:avarra_client/avarra_client.dart';

/// Backend contract implemented by the selected 3D presentation package.
abstract interface class SceneBackend<THandle extends Object> {
  Future<THandle> create(PresentationEntity entity);

  Future<void> update(THandle handle, PresentationEntity entity);

  Future<void> destroy(THandle handle);
}
