import 'dart:async';
import 'dart:typed_data';

import 'package:avarra_core/avarra_core.dart';

import 'network_error_codes.dart';

const int maximumNetworkFrameBytes = 1024 * 1024;

final class NetworkTransportStatistics {
  const NetworkTransportStatistics({
    required this.bytesSent,
    required this.bytesReceived,
    required this.framesSent,
    required this.framesReceived,
  });

  final int bytesSent;
  final int bytesReceived;
  final int framesSent;
  final int framesReceived;
}

abstract interface class NetworkTransportConnection {
  Stream<Uint8List> get frames;
  NetworkTransportStatistics get statistics;
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
  int _bytesSent = 0;
  int _bytesReceived = 0;
  int _framesSent = 0;
  int _framesReceived = 0;

  @override
  Stream<Uint8List> get frames => _controller.stream;

  @override
  NetworkTransportStatistics get statistics => NetworkTransportStatistics(
    bytesSent: _bytesSent,
    bytesReceived: _bytesReceived,
    framesSent: _framesSent,
    framesReceived: _framesReceived,
  );

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
    _bytesSent += frame.length;
    _framesSent += 1;
    _peer._bytesReceived += frame.length;
    _peer._framesReceived += 1;
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
