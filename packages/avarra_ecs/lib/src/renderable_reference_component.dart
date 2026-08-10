import 'package:avarra_core/avarra_core.dart';

/// Renderer-agnostic reference to the visual asset for an entity.
///
/// The client presentation layer resolves the stable asset ID to a backend
/// object. No renderer handle is stored in the ECS.
final class RenderableReferenceComponent {
  RenderableReferenceComponent({required this.assetId});

  final AssetId assetId;
}
