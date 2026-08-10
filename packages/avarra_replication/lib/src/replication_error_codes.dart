import 'package:avarra_core/avarra_core.dart';

abstract final class ReplicationErrorCodes {
  static const invalidConfiguration = AvarraErrorCode(
    'REPLICATION_CONFIGURATION_INVALID',
  );
  static const duplicateEntity = AvarraErrorCode(
    'REPLICATION_ENTITY_DUPLICATE',
  );
  static const entityNotFound = AvarraErrorCode('REPLICATION_ENTITY_NOT_FOUND');
  static const clientNotFound = AvarraErrorCode('REPLICATION_CLIENT_NOT_FOUND');
  static const protocolViolation = AvarraErrorCode(
    'REPLICATION_PROTOCOL_VIOLATION',
  );
  static const joinRejected = AvarraErrorCode('REPLICATION_JOIN_REJECTED');
}
