import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sampleRate = 22050;
const _twoPi = math.pi * 2;

typedef _Synthesizer = double Function(double time, int sampleIndex);

void main() {
  final output = Directory('apps/avarra_game/assets/audio')
    ..createSync(recursive: true);
  final specs = <String, ({double seconds, _Synthesizer synth})>{
    'ashfall_ambience.wav': (
      seconds: 12,
      synth: (time, _) {
        final drone =
            math.sin(_twoPi * 55 * time) * 0.32 +
            math.sin(_twoPi * 81.75 * time) * 0.18 +
            math.sin(_twoPi * 110 * time) * 0.07;
        final breathe =
            0.72 +
            math.sin(_twoPi * time / 12) * 0.16 +
            math.sin(_twoPi * time / 6) * 0.07;
        final wind =
            math.sin(_twoPi * 2.5833333333 * time) * 0.05 +
            math.sin(_twoPi * 3.9166666667 * time + 1.7) * 0.035 +
            math.sin(_twoPi * 6.1666666667 * time + 0.4) * 0.022;
        final distantBell =
            math.pow(math.max(0, math.sin(_twoPi * time / 6)), 18).toDouble() *
            (math.sin(_twoPi * 220 * time) +
                math.sin(_twoPi * 329.6666666667 * time) * 0.45) *
            0.09;
        return drone * breathe + wind + distantBell;
      },
    ),
    'ui_confirm.wav': (
      seconds: 0.14,
      synth: (time, _) {
        final envelope = _attackRelease(time, 0.14, 0.008, 0.11);
        final frequency = 430 + 950 * time;
        return math.sin(_twoPi * frequency * time) * envelope;
      },
    ),
    'player_dodge.wav': (
      seconds: 0.32,
      synth: (time, index) {
        final progress = time / 0.32;
        final envelope = _attackRelease(time, 0.32, 0.008, 0.1);
        final rush = _noise(index, 0xD0D6) * (1 - progress) * 0.58;
        final cut = math.sin(_twoPi * (290 - progress * 170) * time) * 0.34;
        return (rush + cut) * envelope;
      },
    ),
    'relic_mend.wav': (
      seconds: 0.78,
      synth: (time, index) {
        final envelope = _attackRelease(time, 0.78, 0.012, 0.34);
        const notes = [220.0, 329.63, 440.0, 659.25];
        var chime = 0.0;
        for (var note = 0; note < notes.length; note += 1) {
          final start = note * 0.075;
          final local = time - start;
          if (local < 0) continue;
          chime +=
              math.sin(_twoPi * notes[note] * local) *
              math.exp(-local * 5.5) *
              0.26;
        }
        final breath = _noise(index, 0x4D3D) * math.exp(-time * 8) * 0.08;
        return (chime + breath) * envelope;
      },
    ),
    'warden_windup.wav': (
      seconds: 0.65,
      synth: (time, _) {
        final progress = time / 0.65;
        final envelope = _attackRelease(time, 0.65, 0.025, 0.08);
        final frequency = 68 + 155 * progress * progress;
        final pulse = 0.65 + 0.35 * math.sin(_twoPi * 7 * time).abs();
        return envelope *
            pulse *
            (math.sin(_twoPi * frequency * time) * 0.75 +
                math.sin(_twoPi * frequency * 2.73 * time) * 0.25);
      },
    ),
    'combat_hit.wav': (
      seconds: 0.24,
      synth: (time, index) {
        final decay = math.exp(-time * 18);
        final body = math.sin(_twoPi * (92 - time * 190) * time) * 0.8;
        final noise = _noise(index, 0xA51F) * 0.42;
        return (body + noise) * decay;
      },
    ),
    'player_hurt.wav': (
      seconds: 0.38,
      synth: (time, index) {
        final envelope = _attackRelease(time, 0.38, 0.006, 0.28);
        final fall = 145 - 170 * time;
        return envelope *
            (math.sin(_twoPi * fall * time) * 0.72 +
                _noise(index, 0xD06E) * math.exp(-time * 9) * 0.34);
      },
    ),
    'enemy_defeated.wav': (
      seconds: 0.8,
      synth: (time, index) {
        final envelope = _attackRelease(time, 0.8, 0.008, 0.45);
        final fall = 170 - 145 * time;
        return envelope *
            (math.sin(_twoPi * fall * time) * 0.64 +
                math.sin(_twoPi * fall * 1.49 * time) * 0.2 +
                _noise(index, 0xDEAD) * math.exp(-time * 5) * 0.24);
      },
    ),
    'pickup_shard.wav': (
      seconds: 0.72,
      synth: (time, _) {
        const notes = [440.0, 554.37, 659.25, 880.0];
        var value = 0.0;
        for (var note = 0; note < notes.length; note += 1) {
          final start = note * 0.105;
          final local = time - start;
          if (local < 0) continue;
          value +=
              math.sin(_twoPi * notes[note] * local) *
              math.exp(-local * 7) *
              0.42;
        }
        return value;
      },
    ),
    'objective_awakened.wav': (
      seconds: 0.95,
      synth: (time, _) {
        final envelope = _attackRelease(time, 0.95, 0.025, 0.5);
        return envelope *
            (math.sin(_twoPi * 329.63 * time) * 0.38 +
                math.sin(_twoPi * 493.88 * time) * 0.3 +
                math.sin(_twoPi * 659.25 * time) * 0.22);
      },
    ),
    'mission_complete.wav': (
      seconds: 1.65,
      synth: (time, _) {
        const notes = [220.0, 277.18, 329.63, 440.0, 554.37, 659.25];
        var value = 0.0;
        for (var note = 0; note < notes.length; note += 1) {
          final start = note * 0.16;
          final local = time - start;
          if (local < 0) continue;
          value +=
              math.sin(_twoPi * notes[note] * local) *
              math.exp(-local * 2.8) *
              0.3;
        }
        return value;
      },
    ),
    'boss_combat_layer.wav': (
      seconds: 12,
      synth: (time, index) {
        final drive =
            math.sin(_twoPi * 55 * time) * 0.38 +
            math.sin(_twoPi * 82.5 * time) * 0.24 +
            math.sin(_twoPi * 110 * time) * 0.12;
        final pulse =
            0.5 +
            math.pow(math.sin(_twoPi * 2 * time).abs(), 7).toDouble() * 0.5;
        final grit =
            _noise(index, 0xB055) *
            math.pow(math.sin(_twoPi * 0.5 * time).abs(), 10).toDouble() *
            0.12;
        return drive * pulse + grit;
      },
    ),
    'boss_phase_shift.wav': (
      seconds: 0.9,
      synth: (time, index) {
        final progress = time / 0.9;
        final envelope = _attackRelease(time, 0.9, 0.015, 0.3);
        final rise = 76 + 390 * progress * progress;
        return envelope *
            (math.sin(_twoPi * rise * time) * 0.66 +
                math.sin(_twoPi * rise * 1.5 * time) * 0.24 +
                _noise(index, 0xFACE) * math.exp(-time * 5) * 0.18);
      },
    ),
    'boss_defeated.wav': (
      seconds: 1.8,
      synth: (time, index) {
        final envelope = _attackRelease(time, 1.8, 0.008, 0.8);
        final fall = 145 - 58 * time;
        final collapse =
            math.sin(_twoPi * fall * time) * 0.62 +
            math.sin(_twoPi * fall * 0.5 * time) * 0.34;
        final ash = _noise(index, 0xA55E) * math.exp(-time * 2.8) * 0.26;
        return (collapse + ash) * envelope;
      },
    ),
    'boss_melee_windup.wav': (
      seconds: 0.65,
      synth: (time, index) {
        final envelope = _attackRelease(time, 0.65, 0.01, 0.18);
        final body = math.sin(_twoPi * (88 - time * 45) * time) * 0.72;
        final chain = _noise(index, 0xB111) * math.exp(-time * 10) * 0.3;
        return (body + chain) * envelope;
      },
    ),
    'boss_sweep_windup.wav': (
      seconds: 0.9,
      synth: (time, index) {
        final progress = time / 0.9;
        final envelope = _attackRelease(time, 0.9, 0.018, 0.24);
        final air =
            _noise(index, 0xB222) * math.sin(math.pi * progress).abs() * 0.46;
        final blade = math.sin(_twoPi * (120 + progress * 270) * time) * 0.55;
        return (air + blade) * envelope;
      },
    ),
    'boss_eruption_windup.wav': (
      seconds: 1.1,
      synth: (time, index) {
        final progress = time / 1.1;
        final envelope = _attackRelease(time, 1.1, 0.025, 0.16);
        final rise = 48 + 190 * progress * progress;
        final tremor =
            math.sin(_twoPi * rise * time) * 0.64 +
            math.sin(_twoPi * rise * 2.01 * time) * 0.2;
        final grit = _noise(index, 0xB333) * progress * progress * 0.32;
        return (tremor + grit) * envelope;
      },
    ),
    'boss_fissure_ring_windup.wav': (
      seconds: 1.3,
      synth: (time, index) {
        final progress = time / 1.3;
        final envelope = _attackRelease(time, 1.3, 0.02, 0.2);
        final pulse = math.sin(_twoPi * (42 + progress * 26) * time) * 0.54;
        final overtone = math.sin(_twoPi * (84 + progress * 120) * time) * 0.24;
        final fracture =
            _noise(index, 0xB444) * math.pow(progress, 1.7).toDouble() * 0.38;
        return (pulse + overtone + fracture) * envelope;
      },
    ),
  };

  for (final entry in specs.entries) {
    final target = File('${output.path}/${entry.key}');
    _writeWave(target, seconds: entry.value.seconds, synth: entry.value.synth);
    stdout.writeln(
      '${target.path} ${target.lengthSync()} bytes '
      '${entry.value.seconds.toStringAsFixed(2)}s',
    );
  }
}

double _attackRelease(
  double time,
  double duration,
  double attack,
  double release,
) {
  final attackGain = (time / attack).clamp(0, 1);
  final releaseGain = ((duration - time) / release).clamp(0, 1);
  return (attackGain * releaseGain).toDouble();
}

double _noise(int index, int seed) {
  var value = (index + seed) & 0x7fffffff;
  value = (value * 1103515245 + 12345) & 0x7fffffff;
  return value / 0x3fffffff - 1;
}

void _writeWave(
  File target, {
  required double seconds,
  required _Synthesizer synth,
}) {
  final sampleCount = (seconds * _sampleRate).round();
  final samples = Float64List(sampleCount);
  var peak = 0.0;
  for (var index = 0; index < sampleCount; index += 1) {
    final sample = synth(index / _sampleRate, index);
    samples[index] = sample;
    peak = math.max(peak, sample.abs());
  }
  final gain = peak <= 0 ? 0 : 0.88 / peak;
  final dataLength = sampleCount * 2;
  final bytes = ByteData(44 + dataLength);
  _writeAscii(bytes, 0, 'RIFF');
  bytes.setUint32(4, 36 + dataLength, Endian.little);
  _writeAscii(bytes, 8, 'WAVE');
  _writeAscii(bytes, 12, 'fmt ');
  bytes
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, _sampleRate, Endian.little)
    ..setUint32(28, _sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  _writeAscii(bytes, 36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);
  for (var index = 0; index < sampleCount; index += 1) {
    final value = (samples[index] * gain * 32767).round().clamp(-32768, 32767);
    bytes.setInt16(44 + index * 2, value, Endian.little);
  }
  target.writeAsBytesSync(bytes.buffer.asUint8List(), flush: true);
}

void _writeAscii(ByteData bytes, int offset, String text) {
  for (var index = 0; index < text.length; index += 1) {
    bytes.setUint8(offset + index, text.codeUnitAt(index));
  }
}
