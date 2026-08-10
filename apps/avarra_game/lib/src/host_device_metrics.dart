import 'dart:io';

import 'package:flutter/services.dart';

final class HostDeviceMetrics {
  const HostDeviceMetrics({
    required this.memoryBytes,
    required this.thermalStatus,
    required this.platformBytesSent,
    required this.platformBytesReceived,
  });

  final int memoryBytes;
  final String thermalStatus;
  final int? platformBytesSent;
  final int? platformBytesReceived;
}

abstract interface class HostDeviceMetricsSampler {
  Future<HostDeviceMetrics> sample();
}

final class PlatformHostDeviceMetricsSampler
    implements HostDeviceMetricsSampler {
  const PlatformHostDeviceMetricsSampler();

  static const _channel = MethodChannel('dev.avarra/host_metrics');

  @override
  Future<HostDeviceMetrics> sample() async {
    if (!Platform.isAndroid) {
      return HostDeviceMetrics(
        memoryBytes: ProcessInfo.currentRss,
        thermalStatus: 'unavailable',
        platformBytesSent: null,
        platformBytesReceived: null,
      );
    }
    try {
      final values = await _channel.invokeMapMethod<String, Object?>('sample');
      return HostDeviceMetrics(
        memoryBytes: (values?['memoryBytes'] as int?) ?? ProcessInfo.currentRss,
        thermalStatus: (values?['thermalStatus'] as String?) ?? 'unknown',
        platformBytesSent: values?['networkTxBytes'] as int?,
        platformBytesReceived: values?['networkRxBytes'] as int?,
      );
    } on PlatformException {
      return HostDeviceMetrics(
        memoryBytes: ProcessInfo.currentRss,
        thermalStatus: 'unavailable',
        platformBytesSent: null,
        platformBytesReceived: null,
      );
    }
  }
}
