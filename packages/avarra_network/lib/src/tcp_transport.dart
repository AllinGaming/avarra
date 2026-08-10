import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:avarra_core/avarra_core.dart';

import 'network_error_codes.dart';
import 'transport.dart';

/// Provisional reliable ordered adapter. OD-003 remains open.
final class TcpNetworkTransportServer implements NetworkTransportServer {
  TcpNetworkTransportServer._(this._serverSocket) {
    _subscription = _serverSocket.listen(
      (socket) {
        final connection = TcpNetworkTransportConnection._(socket);
        _activeConnections.add(connection);
        _controller.add(connection);
      },
      onError: _controller.addError,
      onDone: _closeController,
    );
  }

  static Future<TcpNetworkTransportServer> bind({
    Object? address,
    int port = 0,
  }) async {
    if (port < 0 || port > 65535) {
      _transportFailure('TCP port must be in [0, 65535].');
    }
    try {
      final server = await ServerSocket.bind(
        address ?? InternetAddress.anyIPv4,
        port,
      );
      return TcpNetworkTransportServer._(server);
    } on SocketException catch (error) {
      _transportFailure('TCP server bind failed.', error: error);
    }
  }

  final ServerSocket _serverSocket;
  final StreamController<NetworkTransportConnection> _controller =
      StreamController.broadcast();
  final Set<TcpNetworkTransportConnection> _activeConnections = {};
  late final StreamSubscription<Socket> _subscription;
  bool _closed = false;

  @override
  int get port => _serverSocket.port;

  @override
  Stream<NetworkTransportConnection> get connections => _controller.stream;

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _subscription.cancel();
    await _serverSocket.close();
    for (final connection in _activeConnections.toList()) {
      await connection.close();
    }
    _activeConnections.clear();
    await _closeController();
  }

  Future<void> _closeController() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}

final class TcpNetworkTransportConnection
    implements NetworkTransportConnection {
  TcpNetworkTransportConnection._(this._socket) {
    _socket.setOption(SocketOption.tcpNoDelay, true);
    _subscription = _socket.listen(
      _handleBytes,
      onError: _handleError,
      onDone: _handleDone,
      cancelOnError: false,
    );
  }

  static Future<TcpNetworkTransportConnection> connect({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (host.trim().isEmpty || port <= 0 || port > 65535) {
      _transportFailure('TCP client endpoint is invalid.');
    }
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      return TcpNetworkTransportConnection._(socket);
    } on SocketException catch (error) {
      _transportFailure('TCP client connection failed.', error: error);
    }
  }

  final Socket _socket;
  final StreamController<Uint8List> _controller = StreamController.broadcast();
  final _LengthFrameDecoder _decoder = _LengthFrameDecoder();
  late final StreamSubscription<Uint8List> _subscription;
  Future<void> _sendQueue = Future.value();
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
  Future<void> send(Uint8List frame) {
    if (_closed) {
      throw AvarraException(
        code: NetworkErrorCodes.transportClosed,
        message: 'TCP network transport is closed.',
      );
    }
    if (frame.isEmpty || frame.length > maximumNetworkFrameBytes) {
      throw AvarraException(
        code: NetworkErrorCodes.frameTooLarge,
        message: 'TCP network frame size is invalid.',
        context: {'length': frame.length},
      );
    }
    final operation = _sendQueue.then((_) async {
      final header = ByteData(4)..setUint32(0, frame.length, Endian.big);
      _socket.add(header.buffer.asUint8List());
      _socket.add(frame);
      await _socket.flush();
      _bytesSent += frame.length + 4;
      _framesSent += 1;
    });
    _sendQueue = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _subscription.cancel();
    await _socket.close();
    await _closeController();
  }

  void _handleBytes(Uint8List bytes) {
    try {
      for (final frame in _decoder.add(bytes)) {
        _bytesReceived += frame.length + 4;
        _framesReceived += 1;
        _controller.add(frame);
      }
    } on Object catch (error, stackTrace) {
      _controller.addError(error, stackTrace);
      _socket.destroy();
      unawaited(_closeController());
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    _controller.addError(error, stackTrace);
  }

  void _handleDone() {
    _closed = true;
    _socket.destroy();
    unawaited(_closeController());
  }

  Future<void> _closeController() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}

final class _LengthFrameDecoder {
  Uint8List _buffer = Uint8List(0);

  List<Uint8List> add(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const [];
    }
    final combined = Uint8List(_buffer.length + bytes.length)
      ..setRange(0, _buffer.length, _buffer)
      ..setRange(_buffer.length, _buffer.length + bytes.length, bytes);
    final frames = <Uint8List>[];
    var offset = 0;
    while (combined.length - offset >= 4) {
      final length = ByteData.sublistView(
        combined,
        offset,
        offset + 4,
      ).getUint32(0, Endian.big);
      if (length == 0 || length > maximumNetworkFrameBytes) {
        throw AvarraException(
          code: NetworkErrorCodes.frameTooLarge,
          message: 'Received TCP frame size is invalid.',
          context: {'length': length},
        );
      }
      if (combined.length - offset - 4 < length) {
        break;
      }
      final start = offset + 4;
      frames.add(Uint8List.fromList(combined.sublist(start, start + length)));
      offset = start + length;
    }
    _buffer = Uint8List.fromList(combined.sublist(offset));
    if (_buffer.length > maximumNetworkFrameBytes + 4) {
      throw AvarraException(
        code: NetworkErrorCodes.frameTooLarge,
        message: 'Buffered TCP frame exceeds the maximum size.',
      );
    }
    return frames;
  }
}

Never _transportFailure(String message, {SocketException? error}) {
  throw AvarraException(
    code: NetworkErrorCodes.transportFailed,
    message: message,
    context: {if (error != null) 'osError': error.osError?.errorCode},
  );
}
