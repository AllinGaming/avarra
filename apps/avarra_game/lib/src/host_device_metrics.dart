import 'dart:io';

import 'package:flutter/services.dart';

final class HostDeviceMetrics {
  const HostDeviceMetrics({
    required this.memoryBytes,
    required this.thermalStatus,
    required this.platformBytesSent,
    required this.platformBytesReceived,
    this.batteryLevelPercent,
    this.batteryCharging,
    this.deviceModel,
    this.operatingSystemVersion,
    this.appVersion,
    this.appBuildNumber,
  });

  final int memoryBytes;
  final String thermalStatus;
  final int? platformBytesSent;
  final int? platformBytesReceived;
  final double? batteryLevelPercent;
  final bool? batteryCharging;
  final String? deviceModel;
  final String? operatingSystemVersion;
  final String? appVersion;
  final String? appBuildNumber;
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
        deviceModel: Platform.operatingSystem,
        operatingSystemVersion: Platform.operatingSystemVersion,
      );
    }
    try {
      final values = await _channel.invokeMapMethod<String, Object?>('sample');
      return HostDeviceMetrics(
        memoryBytes: (values?['memoryBytes'] as int?) ?? ProcessInfo.currentRss,
        thermalStatus: (values?['thermalStatus'] as String?) ?? 'unknown',
        platformBytesSent: values?['networkTxBytes'] as int?,
        platformBytesReceived: values?['networkRxBytes'] as int?,
        batteryLevelPercent: (values?['batteryLevelPercent'] as num?)
            ?.toDouble(),
        batteryCharging: values?['batteryCharging'] as bool?,
        deviceModel: values?['deviceModel'] as String?,
        operatingSystemVersion: values?['operatingSystemVersion'] as String?,
        appVersion: values?['appVersion'] as String?,
        appBuildNumber: values?['appBuildNumber'] as String?,
      );
    } on PlatformException {
      return HostDeviceMetrics(
        memoryBytes: ProcessInfo.currentRss,
        thermalStatus: 'unavailable',
        platformBytesSent: null,
        platformBytesReceived: null,
        deviceModel: Platform.operatingSystem,
        operatingSystemVersion: Platform.operatingSystemVersion,
      );
    }
  }
}
