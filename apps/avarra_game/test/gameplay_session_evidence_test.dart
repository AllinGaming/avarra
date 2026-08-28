import 'package:avarra_game/src/gameplay_session_evidence.dart';
import 'package:avarra_game/src/host_device_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'exports bounded device, performance, state, and human-review evidence',
    () {
      final recorder =
          GameplaySessionEvidenceRecorder(
              startedAtUtc: DateTime.utc(2026, 8, 28, 10),
            )
            ..recordDeviceSample(
              const HostDeviceMetrics(
                memoryBytes: 100 * 1024 * 1024,
                thermalStatus: 'none',
                batteryLevelPercent: 92,
                batteryCharging: false,
                platformBytesSent: 1000,
                platformBytesReceived: 2000,
              ),
            )
            ..recordDeviceSample(
              const HostDeviceMetrics(
                memoryBytes: 140 * 1024 * 1024,
                thermalStatus: 'moderate',
                batteryLevelPercent: 88.5,
                batteryCharging: false,
                platformBytesSent: 3000,
                platformBytesReceived: 5000,
              ),
            )
            ..recordDeviceSample(
              const HostDeviceMetrics(
                memoryBytes: 120 * 1024 * 1024,
                thermalStatus: 'light',
                batteryLevelPercent: 89,
                batteryCharging: true,
                platformBytesSent: 3500,
                platformBytesReceived: 6000,
                deviceModel: 'Google Pixel 10 Pro',
                operatingSystemVersion: 'Android 16 (API 36)',
                appVersion: '1.0.0',
                appBuildNumber: '1',
              ),
            );

      final report = recorder
          .build(
            capturedAtUtc: DateTime.utc(2026, 8, 28, 10, 12, 34),
            sessionDuration: const Duration(minutes: 12, seconds: 34),
            worldName: 'Relay Zero\nInjected heading',
            worldId: '01890f47-e8b8-7a68-8000-000000000301',
            sourceLabel: 'Bundled | world',
            worldFormatVersion: 3,
            contentSchemaVersion: 12,
            networkProtocolVersion: 7,
            sessionMode: 'listen-host',
            rendererReady: true,
            frameSamples: 1000,
            averageFrameMilliseconds: 12.25,
            maximumFrameMilliseconds: 44.5,
            slowFrameCount: 15,
            clampedFrameDeltaCount: 2,
            discardedSimulationStepCount: 3,
            activeChunkCount: 4,
            totalChunkCount: 8,
            currentHealth: 85,
            maximumHealth: 125,
            missionComplete: false,
            missionStatus: 'Defeat Vharos',
            inventoryItemCount: 2,
            interactionStatus: 'Relic Mend restored 35 health',
            completedHostTicks: 22500,
            averageHostTickMilliseconds: 1.2,
            maximumHostTickMilliseconds: 7.8,
            activeClients: 2,
            authoritativeEntityCount: 18,
            hostBytesSent: 4096,
            hostBytesReceived: 8192,
          )
          .toMarkdown();

      expect(report, startsWith('# AVARRA Playtest Evidence'));
      expect(report, contains('Session duration: 00:12:34'));
      expect(report, contains('Relay Zero Injected heading'));
      expect(report, isNot(contains('Bundled | world')));
      expect(report, contains('Device: Google Pixel 10 Pro'));
      expect(report, contains('OS: Android 16 (API 36)'));
      expect(report, contains('App build: 1.0.0 (1)'));
      expect(report, contains('Frame time avg/max: 12.25/44.50 ms'));
      expect(report, contains('Frames over 33.3 ms: 15 (1.5%)'));
      expect(report, contains('Memory current/peak: 120.0/140.0 MiB'));
      expect(report, contains('Thermal current/worst: light/moderate'));
      expect(report, contains('Battery start/end/delta: 92.0%/89.0%/-3.0 pp'));
      expect(report, contains('Movement/input blockers:'));
    },
  );

  test('keeps unavailable physical metrics honest', () {
    final report =
        GameplaySessionEvidenceRecorder(startedAtUtc: DateTime.utc(2026))
            .build(
              capturedAtUtc: DateTime.utc(2026, 1, 1, 0, 0, 1),
              sessionDuration: const Duration(seconds: 1),
              worldName: 'World',
              worldId: 'world.id',
              sourceLabel: 'test',
              worldFormatVersion: 1,
              contentSchemaVersion: 1,
              networkProtocolVersion: 7,
              sessionMode: 'offline',
              rendererReady: false,
              frameSamples: 0,
              averageFrameMilliseconds: null,
              maximumFrameMilliseconds: null,
              slowFrameCount: 0,
              clampedFrameDeltaCount: 0,
              discardedSimulationStepCount: 0,
              activeChunkCount: 0,
              totalChunkCount: 0,
              currentHealth: null,
              maximumHealth: null,
              missionComplete: false,
              missionStatus: 'Unavailable',
              inventoryItemCount: 0,
              interactionStatus: 'None',
            )
            .toMarkdown();

    expect(report, contains('Battery start/end/delta: -/-/-; charging: -'));
    expect(report, contains('Frame time avg/max: -/- ms (0 samples)'));
    expect(report, contains('Host clients/entities: -/-'));
  });
}
