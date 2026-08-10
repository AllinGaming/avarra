import 'dart:io';
import 'dart:typed_data';

import 'package:avarra_network/avarra_network.dart';
import 'package:test/test.dart';

void main() {
  test(
    'memory transport carries isolated frames through protocol channels',
    () async {
      final pair = MemoryNetworkTransportPair.create();
      final sender = NetworkProtocolChannel(connection: pair.first);
      final receiver = NetworkProtocolChannel(connection: pair.second);
      final received = receiver.messages.first;

      await sender.send(
        DespawnEntityMessage(networkEntityId: NetworkEntityId(7)),
      );

      final message = await received;
      expect(message, isA<DespawnEntityMessage>());
      expect((message as DespawnEntityMessage).networkEntityId.value, 7);
      await sender.close();
      await receiver.close();
    },
  );

  test('TCP transport preserves coalesced ordered frame boundaries', () async {
    final server = await TcpNetworkTransportServer.bind(
      address: InternetAddress.loopbackIPv4,
    );
    final accepted = server.connections.first;
    final client = await TcpNetworkTransportConnection.connect(
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
    );
    final host = await accepted;
    final frames = host.frames.take(2).toList();
    final large = Uint8List.fromList(
      List<int>.generate(128 * 1024, (index) => index % 251),
    );
    final small = Uint8List.fromList([1, 2, 3, 4]);

    await Future.wait([client.send(large), client.send(small)]);

    final received = await frames;
    expect(received, [large, small]);
    final remoteClosed = host.frames.drain<void>();
    await client.close();
    await remoteClosed.timeout(const Duration(seconds: 2));
    await host.close();
    await server.close();
  });
}
