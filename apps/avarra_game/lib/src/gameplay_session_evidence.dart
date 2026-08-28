import 'host_device_metrics.dart';

/// Game-owned accumulator for physical-device and human playtest evidence.
///
/// It observes presentation/host metrics only. It never participates in
/// simulation, networking, world content, saves, or gameplay decisions.
final class GameplaySessionEvidenceRecorder {
  GameplaySessionEvidenceRecorder({required DateTime startedAtUtc})
    : startedAtUtc = startedAtUtc.toUtc();

  final DateTime startedAtUtc;
  HostDeviceMetrics? _initialDevice;
  HostDeviceMetrics? _latestDevice;
  int? _peakMemoryBytes;
  String? _worstThermalStatus;

  void recordDeviceSample(HostDeviceMetrics sample) {
    _initialDevice ??= sample;
    _latestDevice = sample;
    final peak = _peakMemoryBytes;
    if (peak == null || sample.memoryBytes > peak) {
      _peakMemoryBytes = sample.memoryBytes;
    }
    final worst = _worstThermalStatus;
    if (worst == null ||
        _thermalSeverity(sample.thermalStatus) > _thermalSeverity(worst)) {
      _worstThermalStatus = sample.thermalStatus;
    }
  }

  GameplaySessionEvidence build({
    required DateTime capturedAtUtc,
    required Duration sessionDuration,
    required String worldName,
    required String worldId,
    required String sourceLabel,
    required int worldFormatVersion,
    required int contentSchemaVersion,
    required int networkProtocolVersion,
    required String sessionMode,
    required bool rendererReady,
    required int frameSamples,
    required double? averageFrameMilliseconds,
    required double? maximumFrameMilliseconds,
    required int slowFrameCount,
    required int clampedFrameDeltaCount,
    required int discardedSimulationStepCount,
    required int activeChunkCount,
    required int totalChunkCount,
    required double? currentHealth,
    required double? maximumHealth,
    required bool missionComplete,
    required String missionStatus,
    required int inventoryItemCount,
    required String interactionStatus,
    int? completedHostTicks,
    double? averageHostTickMilliseconds,
    double? maximumHostTickMilliseconds,
    int? activeClients,
    int? authoritativeEntityCount,
    int? hostBytesSent,
    int? hostBytesReceived,
  }) => GameplaySessionEvidence(
    startedAtUtc: startedAtUtc,
    capturedAtUtc: capturedAtUtc.toUtc(),
    sessionDuration: sessionDuration,
    worldName: worldName,
    worldId: worldId,
    sourceLabel: sourceLabel,
    worldFormatVersion: worldFormatVersion,
    contentSchemaVersion: contentSchemaVersion,
    networkProtocolVersion: networkProtocolVersion,
    sessionMode: sessionMode,
    rendererReady: rendererReady,
    frameSamples: frameSamples,
    averageFrameMilliseconds: averageFrameMilliseconds,
    maximumFrameMilliseconds: maximumFrameMilliseconds,
    slowFrameCount: slowFrameCount,
    clampedFrameDeltaCount: clampedFrameDeltaCount,
    discardedSimulationStepCount: discardedSimulationStepCount,
    activeChunkCount: activeChunkCount,
    totalChunkCount: totalChunkCount,
    currentHealth: currentHealth,
    maximumHealth: maximumHealth,
    missionComplete: missionComplete,
    missionStatus: missionStatus,
    inventoryItemCount: inventoryItemCount,
    interactionStatus: interactionStatus,
    completedHostTicks: completedHostTicks,
    averageHostTickMilliseconds: averageHostTickMilliseconds,
    maximumHostTickMilliseconds: maximumHostTickMilliseconds,
    activeClients: activeClients,
    authoritativeEntityCount: authoritativeEntityCount,
    hostBytesSent: hostBytesSent,
    hostBytesReceived: hostBytesReceived,
    initialDevice: _initialDevice,
    latestDevice: _latestDevice,
    peakMemoryBytes: _peakMemoryBytes,
    worstThermalStatus: _worstThermalStatus,
  );
}

final class GameplaySessionEvidence {
  const GameplaySessionEvidence({
    required this.startedAtUtc,
    required this.capturedAtUtc,
    required this.sessionDuration,
    required this.worldName,
    required this.worldId,
    required this.sourceLabel,
    required this.worldFormatVersion,
    required this.contentSchemaVersion,
    required this.networkProtocolVersion,
    required this.sessionMode,
    required this.rendererReady,
    required this.frameSamples,
    required this.averageFrameMilliseconds,
    required this.maximumFrameMilliseconds,
    required this.slowFrameCount,
    required this.clampedFrameDeltaCount,
    required this.discardedSimulationStepCount,
    required this.activeChunkCount,
    required this.totalChunkCount,
    required this.currentHealth,
    required this.maximumHealth,
    required this.missionComplete,
    required this.missionStatus,
    required this.inventoryItemCount,
    required this.interactionStatus,
    required this.completedHostTicks,
    required this.averageHostTickMilliseconds,
    required this.maximumHostTickMilliseconds,
    required this.activeClients,
    required this.authoritativeEntityCount,
    required this.hostBytesSent,
    required this.hostBytesReceived,
    required this.initialDevice,
    required this.latestDevice,
    required this.peakMemoryBytes,
    required this.worstThermalStatus,
  });

  final DateTime startedAtUtc;
  final DateTime capturedAtUtc;
  final Duration sessionDuration;
  final String worldName;
  final String worldId;
  final String sourceLabel;
  final int worldFormatVersion;
  final int contentSchemaVersion;
  final int networkProtocolVersion;
  final String sessionMode;
  final bool rendererReady;
  final int frameSamples;
  final double? averageFrameMilliseconds;
  final double? maximumFrameMilliseconds;
  final int slowFrameCount;
  final int clampedFrameDeltaCount;
  final int discardedSimulationStepCount;
  final int activeChunkCount;
  final int totalChunkCount;
  final double? currentHealth;
  final double? maximumHealth;
  final bool missionComplete;
  final String missionStatus;
  final int inventoryItemCount;
  final String interactionStatus;
  final int? completedHostTicks;
  final double? averageHostTickMilliseconds;
  final double? maximumHostTickMilliseconds;
  final int? activeClients;
  final int? authoritativeEntityCount;
  final int? hostBytesSent;
  final int? hostBytesReceived;
  final HostDeviceMetrics? initialDevice;
  final HostDeviceMetrics? latestDevice;
  final int? peakMemoryBytes;
  final String? worstThermalStatus;

  String toMarkdown() {
    final initialBattery = initialDevice?.batteryLevelPercent;
    final latestBattery = latestDevice?.batteryLevelPercent;
    final batteryDelta = initialBattery == null || latestBattery == null
        ? null
        : latestBattery - initialBattery;
    final slowFraction = frameSamples == 0
        ? null
        : slowFrameCount / frameSamples * 100;
    final buffer = StringBuffer()
      ..writeln('# AVARRA Playtest Evidence')
      ..writeln()
      ..writeln('- Captured UTC: ${capturedAtUtc.toIso8601String()}')
      ..writeln('- Started UTC: ${startedAtUtc.toIso8601String()}')
      ..writeln('- Session duration: ${_durationLabel(sessionDuration)}')
      ..writeln('- Mode: ${_inline(sessionMode)}')
      ..writeln('- World: ${_inline(worldName)} (`${_inline(worldId)}`)')
      ..writeln('- Source: ${_inline(sourceLabel)}')
      ..writeln(
        '- Formats: world v$worldFormatVersion, content v$contentSchemaVersion, protocol v$networkProtocolVersion',
      )
      ..writeln('- Device: ${_inline(latestDevice?.deviceModel ?? '-')}')
      ..writeln('- OS: ${_inline(latestDevice?.operatingSystemVersion ?? '-')}')
      ..writeln('- App build: ${_appBuild(latestDevice)}')
      ..writeln()
      ..writeln('## Performance')
      ..writeln()
      ..writeln('- Renderer ready: ${rendererReady ? 'yes' : 'no'}')
      ..writeln(
        '- Frame time avg/max: ${_milliseconds(averageFrameMilliseconds)}/${_milliseconds(maximumFrameMilliseconds)} ms ($frameSamples samples)',
      )
      ..writeln(
        '- Frames over 33.3 ms: $slowFrameCount${slowFraction == null ? '' : ' (${slowFraction.toStringAsFixed(1)}%)'}',
      )
      ..writeln('- Clamped frame deltas: $clampedFrameDeltaCount')
      ..writeln('- Discarded simulation steps: $discardedSimulationStepCount')
      ..writeln(
        '- Host tick avg/max: ${_milliseconds(averageHostTickMilliseconds)}/${_milliseconds(maximumHostTickMilliseconds)} ms (${completedHostTicks ?? '-'} ticks)',
      )
      ..writeln(
        '- Memory current/peak: ${_mebibytes(latestDevice?.memoryBytes)}/${_mebibytes(peakMemoryBytes)} MiB',
      )
      ..writeln(
        '- Thermal current/worst: ${_inline(latestDevice?.thermalStatus ?? '-')}/${_inline(worstThermalStatus ?? '-')}',
      )
      ..writeln(
        '- Battery start/end/delta: ${_percent(initialBattery)}/${_percent(latestBattery)}/${_signedPercent(batteryDelta)}; charging: ${_charging(latestDevice?.batteryCharging)}',
      )
      ..writeln(
        '- Host network sent/received: ${_bytes(hostBytesSent)}/${_bytes(hostBytesReceived)}',
      )
      ..writeln(
        '- Device network sent/received: ${_bytes(latestDevice?.platformBytesSent)}/${_bytes(latestDevice?.platformBytesReceived)}',
      )
      ..writeln()
      ..writeln('## Session state')
      ..writeln()
      ..writeln(
        '- Host clients/entities: ${activeClients ?? '-'}/${authoritativeEntityCount ?? '-'}',
      )
      ..writeln('- Active chunks: $activeChunkCount/$totalChunkCount')
      ..writeln(
        '- Player health: ${_number(currentHealth)}/${_number(maximumHealth)}',
      )
      ..writeln('- Mission complete: ${missionComplete ? 'yes' : 'no'}')
      ..writeln('- Mission: ${_inline(missionStatus)}')
      ..writeln('- Inventory items: $inventoryItemCount')
      ..writeln('- Last interaction: ${_inline(interactionStatus)}')
      ..writeln()
      ..writeln('## Human observations (fill in after play)')
      ..writeln()
      ..writeln('- Movement/input blockers:')
      ..writeln('- Touch/controller comfort:')
      ..writeln('- Combat, dodge, and Relic Mend pacing:')
      ..writeln('- Boss readability and difficulty:')
      ..writeln('- Story/menu clarity:')
      ..writeln('- Audio/haptic quality:')
      ..writeln('- Direct-LAN, reconnect, and resume behavior:')
      ..writeln('- Reproduction steps for any critical issue:');
    return buffer.toString();
  }
}

int _thermalSeverity(String value) => switch (value.trim().toLowerCase()) {
  'none' => 1,
  'light' => 2,
  'moderate' => 3,
  'severe' => 4,
  'critical' => 5,
  'emergency' => 6,
  'shutdown' => 7,
  _ => 0,
};

String _inline(String value) {
  final sanitized = value
      .replaceAll('`', "'")
      .replaceAll(RegExp(r'[\r\n\t|]+'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  if (sanitized.isEmpty) return '-';
  return sanitized.length <= 160
      ? sanitized
      : '${sanitized.substring(0, 157)}...';
}

String _durationLabel(Duration value) {
  final totalSeconds = value.inSeconds.clamp(0, 359999);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

String _milliseconds(double? value) =>
    value == null || !value.isFinite ? '-' : value.toStringAsFixed(2);

String _mebibytes(int? bytes) => bytes == null || bytes < 0
    ? '-'
    : (bytes / (1024 * 1024)).toStringAsFixed(1);

String _percent(double? value) =>
    value == null || !value.isFinite ? '-' : '${value.toStringAsFixed(1)}%';

String _signedPercent(double? value) => value == null || !value.isFinite
    ? '-'
    : '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)} pp';

String _charging(bool? value) => value == null ? '-' : (value ? 'yes' : 'no');

String _appBuild(HostDeviceMetrics? device) {
  final version = device?.appVersion;
  final build = device?.appBuildNumber;
  if (version == null && build == null) return '-';
  if (version == null) return _inline(build!);
  if (build == null) return _inline(version);
  return '${_inline(version)} (${_inline(build)})';
}

String _number(double? value) {
  if (value == null || !value.isFinite) return '-';
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

String _bytes(int? value) => value == null || value < 0 ? '-' : '$value B';
