import 'package:avarra_core/avarra_core.dart';

abstract final class NetworkErrorCodes {
  static const invalidValue = AvarraErrorCode('NET_VALUE_INVALID');
  static const malformedMessage = AvarraErrorCode('NET_MESSAGE_MALFORMED');
  static const unsupportedWireVersion = AvarraErrorCode(
    'NET_WIRE_VERSION_UNSUPPORTED',
  );
  static const frameTooLarge = AvarraErrorCode('NET_FRAME_TOO_LARGE');
  static const transportClosed = AvarraErrorCode('NET_TRANSPORT_CLOSED');
  static const transportFailed = AvarraErrorCode('NET_TRANSPORT_FAILED');
}
