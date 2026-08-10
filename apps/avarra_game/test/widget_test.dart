import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/main.dart';
import 'package:avarra_game/src/host_device_metrics.dart';
import 'package:avarra_network/avarra_network.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:avarra_replication/avarra_replication.dart';
import 'package:avarra_server/avarra_server.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the bundled world into the Game shell', (tester) async {
    await tester.pumpWidget(
      AvarraGameApp(
        enableRenderer: false,
        saveStoreLoader: () async => MemorySaveStore(),
      ),
    );
    await _pumpUntilSaveReady(tester);

    expect(find.text('AVARRA'), findsOneWidget);
    expect(find.text('Stage 9 · Android Listen Host'), findsOneWidget);
    expect(find.text('Isometric Persistence Proof'), findsOneWidget);
    expect(find.text('4 ECS entities bound to the scene'), findsOneWidget);
    expect(
      find.text('Tap ground to move · WASD/arrow keys for direct movement'),
      findsOneWidget,
    );
    expect(find.text('Select the console, then interact'), findsOneWidget);
    expect(find.byKey(const Key('camera_status')), findsOneWidget);
    expect(find.byKey(const Key('world_version_status')), findsOneWidget);
    expect(find.text('Chunk 0,0 · 1/3 active'), findsOneWidget);
    expect(find.byKey(const Key('streaming_status')), findsOneWidget);
    expect(find.text('Save r0 · No save yet'), findsOneWidget);
    expect(find.text('Ancient console: inactive'), findsOneWidget);
    expect(find.byKey(const Key('save_status')), findsOneWidget);
    expect(
      find.text('Network: Offline · local authority · 0 entities'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('multiplayer_status')), findsOneWidget);
    expect(find.byKey(const Key('persistent_console_status')), findsOneWidget);
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
    expect(find.text('Ancient console: activated'), findsOneWidget);
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
  for (var attempt = 0; attempt < 100; attempt += 1) {
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
  fail('Game bootstrap did not expose Stage 9 status.');
}
