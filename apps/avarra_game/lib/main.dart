import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_ecs/avarra_ecs.dart';
import 'package:avarra_thermion_bridge/avarra_thermion_bridge.dart';
import 'package:flutter/material.dart';

const _proofEntityIdValue = '01890f47-e8b8-7a68-8000-000000000001';
const _proofAssetIdValue = '01890f47-e8b8-7a68-9000-000000000001';

void main() {
  runApp(const AvarraGameApp());
}

class AvarraGameApp extends StatelessWidget {
  const AvarraGameApp({this.enableRenderer = true, super.key});

  final bool enableRenderer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '$avarraProductName Game',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF70B7A5),
        ),
      ),
      home: _PresentationBoundaryScreen(enableRenderer: enableRenderer),
    );
  }
}

class _PresentationBoundaryScreen extends StatefulWidget {
  const _PresentationBoundaryScreen({required this.enableRenderer});

  final bool enableRenderer;

  @override
  State<_PresentationBoundaryScreen> createState() {
    return _PresentationBoundaryScreenState();
  }
}

class _PresentationBoundaryScreenState
    extends State<_PresentationBoundaryScreen> {
  late final PresentationSnapshot _presentation;
  late final ThermionAssetUriResolver _assetUriResolver;

  @override
  void initState() {
    super.initState();
    _presentation = _createPresentationProof();
    _assetUriResolver = MapThermionAssetUriResolver({
      AssetId.parse(_proofAssetIdValue): 'asset://assets/models/cube/Cube.gltf',
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final status = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(avarraProductName, style: textTheme.headlineMedium),
        const SizedBox(height: 4),
        const Text('Stage 2B · Thermion Renderer'),
        Text('${_presentation.length} ECS entity bound to the scene'),
      ],
    );

    if (!widget.enableRenderer) {
      return Scaffold(body: Center(child: status));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AvarraThermionViewport(
            snapshot: _presentation,
            assetUriResolver: _assetUriResolver,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Card(
                margin: const EdgeInsets.all(16),
                color: Colors.black.withValues(alpha: 0.72),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: status,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

PresentationSnapshot _createPresentationProof() {
  final world = EcsWorld();
  final entity = world.createEntity(
    entityId: EntityId.parse(_proofEntityIdValue),
  );
  world
    ..addComponent(entity, TransformComponent())
    ..addComponent(
      entity,
      RenderableReferenceComponent(assetId: AssetId.parse(_proofAssetIdValue)),
    );
  return const PresentationExtractor().extract(world);
}
