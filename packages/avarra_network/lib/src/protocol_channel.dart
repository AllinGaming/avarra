import 'dart:async';

import 'protocol_codec.dart';
import 'protocol_messages.dart';
import 'transport.dart';

final class NetworkProtocolChannel {
  NetworkProtocolChannel({
    required this.connection,
    this.codec = const NetworkProtocolCodec(),
  }) {
    _subscription = connection.frames.listen(
      _handleFrame,
      onError: _controller.addError,
      onDone: _closeController,
      cancelOnError: false,
    );
  }

  final NetworkTransportConnection connection;
  final NetworkProtocolCodec codec;
  final StreamController<NetworkMessage> _controller =
      StreamController.broadcast();
  late final StreamSubscription<Object?> _subscription;
  bool _closed = false;

  Stream<NetworkMessage> get messages => _controller.stream;

  Future<void> send(NetworkMessage message) {
    return connection.send(codec.encode(message));
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _subscription.cancel();
    await connection.close();
    await _closeController();
  }

  void _handleFrame(List<int> frame) {
    try {
      _controller.add(codec.decode(frame));
    } on Object catch (error, stackTrace) {
      _controller.addError(error, stackTrace);
    }
  }

  Future<void> _closeController() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
