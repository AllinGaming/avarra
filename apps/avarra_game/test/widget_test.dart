import 'dart:convert';
import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/main.dart';
import 'package:avarra_game/src/host_device_metrics.dart';
import 'package:avarra_game/src/runtime_world_library.dart';
import 'package:avarra_game/src/world_library_ui.dart';
import 'package:avarra_network/avarra_network.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:avarra_replication/avarra_replication.dart';
import 'package:avarra_server/avarra_server.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the bundled world into the Game shell', (tester) async {
    final bundledSource = await tester.runAsync(
      () => File('assets/worlds/isometric_proof.avarra').readAsString(),
    );
    await tester.pumpWidget(
      AvarraGameApp(
        enableRenderer: false,
        saveStoreLoader: () async => MemorySaveStore(),
        worldPackageSourceLoader: () async => bundledSource!,
      ),
    );
    await _pumpUntilSaveReady(tester);

    expect(find.text('AVARRA'), findsOneWidget);
    expect(find.text('Stage 11.2 · Relay Zero Guardian'), findsOneWidget);
    expect(find.text('Relay Zero Prototype'), findsOneWidget);
    expect(find.byKey(const Key('world_source_status')), findsOneWidget);
    expect(find.byKey(const Key('open_world_library')), findsOneWidget);
    expect(find.text('5 ECS entities bound to the scene'), findsOneWidget);
    expect(
      find.text('Tap ground to move · WASD/arrow keys for direct movement'),
      findsOneWidget,
    );
    expect(find.text('Select a world object, then interact'), findsOneWidget);
    expect(
      find.text('Health 100/100 · Select the guardian and attack'),
      findsOneWidget,
    );
    expect(find.text('Guardian: idle · 50/50 health'), findsOneWidget);
    expect(find.byKey(const Key('camera_status')), findsOneWidget);
    expect(find.byKey(const Key('world_version_status')), findsOneWidget);
    expect(find.text('Chunk 0,0 · 1/3 active'), findsOneWidget);
    expect(find.byKey(const Key('streaming_status')), findsOneWidget);
    expect(find.text('Save r0 · No save yet'), findsOneWidget);
    expect(
      find.text('Objectives · 0/1 complete · Next: Restore the ancient relay'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('save_status')), findsOneWidget);
    expect(
      find.text('Network: Offline · local authority · 0 entities'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('multiplayer_status')), findsOneWidget);
    expect(find.byKey(const Key('authored_objective_status')), findsOneWidget);
  });

  testWidgets('restores a persistent entity overlay during chunk activation', (
    tester,
  ) async {
    final store = MemorySaveStore();
    final worldSource = await tester.runAsync(
      () => File('assets/worlds/isometric_proof.avarra').readAsString(),
    );
    await SaveRepository(store: store).save(
      WorldSave(
        saveId: SaveId.parse('01890f47-e8b8-7a68-8000-000000000401'),
        worldId: WorldId.parse('01890f47-e8b8-7a68-8000-000000000010'),
        sourceWorldFormatVersion: 2,
        revision: 4,
        savedAtUtc: DateTime.utc(2026, 8, 10),
        entities: [
          EntitySaveState(
            entityId: EntityId.parse('01890f47-e8b8-7a68-8000-000000000004'),
            flags: const {'activated': true},
          ),
        ],
        players: const [],
      ),
    );

    await tester.pumpWidget(
      AvarraGameApp(
        enableRenderer: false,
        saveStoreLoader: () async => store,
        worldPackageSourceLoader: () async => worldSource!,
      ),
    );
    await _pumpUntilSaveReady(tester);

    expect(find.text('Save r4 · Restored revision 4'), findsOneWidget);
    expect(find.text('Objectives · 1/1 complete'), findsOneWidget);
  });

  testWidgets('does not report an unloaded guardian as defeated', (
    tester,
  ) async {
    final store = MemorySaveStore();
    final worldSource = await tester.runAsync(
      () => File('assets/worlds/isometric_proof.avarra').readAsString(),
    );
    await SaveRepository(store: store).save(
      WorldSave(
        saveId: SaveId.parse('01890f47-e8b8-7a68-8000-000000000401'),
        worldId: WorldId.parse('01890f47-e8b8-7a68-8000-000000000010'),
        sourceWorldFormatVersion: 2,
        revision: 2,
        savedAtUtc: DateTime.utc(2026, 8, 13),
        entities: const [],
        players: [
          PlayerSave(
            playerId: PlayerId.parse('01890f47-e8b8-7a68-8000-000000000402'),
            entityId: EntityId.parse('01890f47-e8b8-7a68-8000-000000000001'),
            position: SaveWorldPosition(
              chunkX: 0,
              chunkZ: -1,
              localX: 1,
              localY: 0.45,
              localZ: 1,
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      AvarraGameApp(
        enableRenderer: false,
        saveStoreLoader: () async => store,
        worldPackageSourceLoader: () async => worldSource!,
      ),
    );
    await _pumpUntilSaveReady(tester);

    expect(
      find.text(
        'Health 100/100 · Guardian outside the active area · '
        'return to the relay',
      ),
      findsOneWidget,
    );
  });

  testWidgets('surfaces malformed world packages', (tester) async {
    await tester.pumpWidget(
      AvarraGameApp(
        enableRenderer: false,
        saveStoreLoader: () async => MemorySaveStore(),
        worldPackageSourceLoader: () async => '{not json',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('world_load_error')), findsOneWidget);
    expect(find.textContaining('WORLD_PACKAGE_MALFORMED'), findsOneWidget);
  });

  testWidgets('keeps world-library failures visible and recoverable', (
    tester,
  ) async {
    final bundledSource = await tester.runAsync(
      () => File('assets/worlds/isometric_proof.avarra').readAsString(),
    );
    await tester.pumpWidget(
      AvarraGameApp(
        enableRenderer: false,
        saveStoreLoader: () async => MemorySaveStore(),
        worldPackageSourceLoader: () async => bundledSource!,
        worldLibraryOpener: (_) async => throw AvarraException(
          code: RuntimeWorldLibraryErrorCodes.assetUnavailable,
          message: 'Missing imported asset.',
        ),
      ),
    );
    await _pumpUntilSaveReady(tester);

    await tester.tap(find.byKey(const Key('open_world_library')));
    await tester.pumpAndSettle();

    expect(find.text('World library error'), findsOneWidget);
    expect(
      find.textContaining('GAME_WORLD_IMPORT_ASSET_UNAVAILABLE'),
      findsOneWidget,
    );
  });

  testWidgets('boots the selected imported world after a library restart', (
    tester,
  ) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('avarra-game-widget-library-'),
    );
    addTearDown(() => directory!.delete(recursive: true));
    final source = await tester.runAsync(
      () => File('assets/worlds/isometric_proof.avarra').readAsString(),
    );
    final json = jsonDecode(source!) as Map<String, dynamic>;
    final world = json['world']! as Map<String, dynamic>;
    world['id'] = '01890f47-e8b8-7a68-8000-000000000790';
    world['name'] = 'Imported Relay Test';

    final firstLibrary = RuntimeWorldLibrary(
      directory: directory!,
      assetAvailability: (_) async => true,
    );
    await tester.runAsync(() => firstLibrary.importSource(jsonEncode(json)));

    final restartedLibrary = RuntimeWorldLibrary(
      directory: directory,
      assetAvailability: (_) async => true,
    );
    final restartedSelection = await tester.runAsync(
      restartedLibrary.loadSelected,
    );
    await tester.pumpWidget(
      AvarraGameApp(
        enableRenderer: false,
        saveStoreLoader: () async => MemorySaveStore(),
        worldSelectionLoader: () async => RuntimeWorldSelection(
          source: restartedSelection!.source,
          label: restartedSelection.name,
          isImported: true,
        ),
      ),
    );
    await _pumpUntilSaveReady(tester);

    expect(find.text('Imported Relay Test'), findsOneWidget);
    expect(find.text('World source: Imported Relay Test'), findsOneWidget);
  });

  testWidgets('rejects a decoded world outside the playable profile', (
    tester,
  ) async {
    final source = await tester.runAsync(
      () => File('assets/worlds/isometric_proof.avarra').readAsString(),
    );
    final json = jsonDecode(source!) as Map<String, dynamic>;
    json['worldFormatVersion'] = 1;
    (json['world']! as Map<String, dynamic>).remove('chunkSize');
    json.remove('chunks');

    await tester.pumpWidget(
      AvarraGameApp(
        enableRenderer: false,
        saveStoreLoader: () async => MemorySaveStore(),
        worldPackageSourceLoader: () async => jsonEncode(json),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('world_load_error')), findsOneWidget);
    expect(
      find.textContaining('WORLD_PLAYABLE_FORMAT_UNSUPPORTED'),
      findsOneWidget,
    );
  });

  testWidgets('runs a local client inside a listen-host session', (
    tester,
  ) async {
    final source = await tester.runAsync(
      () => File('assets/worlds/isometric_proof.avarra').readAsString(),
    );
    final primaryPlayerId = PlayerId.parse(
      '01890f47-e8b8-7a68-8000-000000000402',
    );
    final host = (await tester.runAsync(
      () => MultiplayerProofHost.start(
        worldPackageSource: source!,
        primaryPlayerId: primaryPlayerId,
        bindAddress: InternetAddress.loopbackIPv4,
        port: 0,
      ),
    ))!;
    final client = (await tester.runAsync(() async {
      final connection = await TcpNetworkTransportConnection.connect(
        host: InternetAddress.loopbackIPv4.address,
        port: host.port,
      );
      final value = await ReplicationClient.connectAndJoin(
        connection: connection,
        playerId: primaryPlayerId,
        content: host.content,
      );
      await value.waitForControlledEntity();
      return value;
    }))!;
    await tester.pumpWidget(
      AvarraGameApp(
        enableRenderer: false,
        saveStoreLoader: () async => MemorySaveStore(),
        worldPackageSourceLoader: () async => source!,
        multiplayerHostStarter: (_, _) async => host,
        multiplayerClientConnector: (_, _) async => client,
        hostDeviceMetricsSampler: const _FakeHostDeviceMetricsSampler(),
      ),
    );
    await _pumpUntilSaveReady(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.textContaining('Network: Joined connection 1'), findsOneWidget);
    expect(find.textContaining('Host: Listening '), findsOneWidget);
    expect(find.byKey(const Key('host_performance')), findsOneWidget);
    expect(
      find.textContaining('Device: 64.0 MiB · thermal none'),
      findsOneWidget,
    );
    expect(host.metrics.activeClients, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 75)),
    );
    expect(host.isClosed, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  });
}

final class _FakeHostDeviceMetricsSampler implements HostDeviceMetricsSampler {
  const _FakeHostDeviceMetricsSampler();

  @override
  Future<HostDeviceMetrics> sample() async {
    return const HostDeviceMetrics(
      memoryBytes: 64 * 1024 * 1024,
      thermalStatus: 'none',
      platformBytesSent: 2048,
      platformBytesReceived: 4096,
    );
  }
}

Future<void> _pumpUntilSaveReady(WidgetTester tester) async {
  for (var attempt = 0; attempt < 250; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byKey(const Key('save_status')).evaluate().isNotEmpty) {
      return;
    }
    final errorFinder = find.byKey(const Key('world_load_error'));
    if (errorFinder.evaluate().isNotEmpty) {
      final errorText = tester.widget<Text>(errorFinder).data;
      fail('Game bootstrap failed: $errorText');
    }
  }
  fail('Game bootstrap did not expose Stage 11.2 status.');
}
