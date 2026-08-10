import 'dart:async';
import 'dart:typed_data';

import 'package:avarra_core/avarra_core.dart';

import 'network_error_codes.dart';

const int maximumNetworkFrameBytes = 1024 * 1024;

abstract interface class NetworkTransportConnection {
  Stream<Uint8List> get frames;
  Future<void> send(Uint8List frame);
  Future<void> close();
}

abstract interface class NetworkTransportServer {
  int get port;
  Stream<NetworkTransportConnection> get connections;
  Future<void> close();
}

final class MemoryNetworkTransportPair {
  MemoryNetworkTransportPair._({required this.first, required this.second});

  factory MemoryNetworkTransportPair.create() {
    final first = _MemoryNetworkTransportConnection();
    final second = _MemoryNetworkTransportConnection();
    first._peer = second;
    second._peer = first;
    return MemoryNetworkTransportPair._(first: first, second: second);
  }

  final NetworkTransportConnection first;
  final NetworkTransportConnection second;
}

final class _MemoryNetworkTransportConnection
    implements NetworkTransportConnection {
  final StreamController<Uint8List> _controller = StreamController.broadcast();
  late final _MemoryNetworkTransportConnection _peer;
  bool _closed = false;

  @override
  Stream<Uint8List> get frames => _controller.stream;

  @override
  Future<void> send(Uint8List frame) async {
    if (_closed || _peer._closed) {
      throw AvarraException(
        code: NetworkErrorCodes.transportClosed,
        message: 'Memory network transport is closed.',
      );
    }
    if (frame.isEmpty || frame.length > maximumNetworkFrameBytes) {
      throw AvarraException(
        code: NetworkErrorCodes.frameTooLarge,
        message: 'Memory network frame size is invalid.',
      );
    }
    _peer._controller.add(Uint8List.fromList(frame));
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    final closures = <Future<void>>[];
    if (!_controller.isClosed) {
      closures.add(_controller.close());
    }
    if (!_peer._controller.isClosed) {
      closures.add(_peer._controller.close());
    }
    await Future.wait(closures);
  }
}
