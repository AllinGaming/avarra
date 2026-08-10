import 'dart:async';

import 'package:avarra_client/avarra_client.dart';
import 'package:avarra_scene_bridge/avarra_scene_bridge.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

import 'thermion_asset_uri_resolver.dart';
import 'thermion_scene_backend.dart';

/// Flutter viewport that synchronizes an AVARRA presentation snapshot to
/// Thermion while keeping Thermion objects behind the scene bridge.
final class AvarraThermionViewport extends StatefulWidget {
  const AvarraThermionViewport({
    required this.snapshot,
    required this.assetUriResolver,
    super.key,
  });

  final PresentationSnapshot snapshot;
  final ThermionAssetUriResolver assetUriResolver;

  @override
  State<AvarraThermionViewport> createState() {
    return _AvarraThermionViewportState();
  }
}

final class _AvarraThermionViewportState extends State<AvarraThermionViewport> {
  // Thermion compares these configuration objects during widget updates and
  // rejects identity changes at runtime. Keep them stable for this State's
  // entire lifetime instead of recreating them from build().
  final Vector3 _initialCameraPosition = Vector3(4, 3, 6);
  final DirectLight _directLight = DirectLight.sun();
  SceneBridge<ThermionSceneObject>? _bridge;
  Future<void> _syncTail = Future<void>.value();
  Object? _error;
  bool _ready = false;

  @override
  void didUpdateWidget(AvarraThermionViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot && _bridge != null) {
      unawaited(_queueSynchronization(widget.snapshot));
    }
  }

  Future<void> _onViewerAvailable(ThermionViewer viewer) async {
    final backend = ThermionSceneBackend(
      viewer: viewer,
      assetUriResolver: widget.assetUriResolver,
    );
    _bridge = SceneBridge<ThermionSceneObject>(backend: backend);
    await _queueSynchronization(widget.snapshot);
  }

  Future<void> _queueSynchronization(PresentationSnapshot snapshot) {
    _syncTail = _syncTail.then((_) async {
      final bridge = _bridge;
      if (bridge == null) {
        return;
      }
      try {
        await bridge.synchronize(snapshot);
        if (mounted) {
          setState(() {
            _error = null;
            _ready = true;
          });
        }
      } on Object catch (error) {
        if (mounted) {
          setState(() {
            _error = error;
            _ready = false;
          });
        }
      }
    });
    return _syncTail;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ViewerWidget(
          initial: const ColoredBox(
            color: Color(0xFF101820),
            child: Center(child: CircularProgressIndicator()),
          ),
          initialCameraPosition: _initialCameraPosition,
          directLight: _directLight,
          manipulatorType: ManipulatorType.NONE,
          background: const Color(0xFF101820),
          destroyEngineOnUnload: true,
          onViewerAvailable: _onViewerAvailable,
        ),
        if (!_ready || _error != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error == null
                    ? 'Initializing 3D scene…'
                    : '3D scene initialization failed: $_error',
              ),
            ),
          ),
      ],
    );
  }
}
