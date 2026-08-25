import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main(List<String> arguments) {
  if (arguments.contains('--help')) {
    stdout.writeln(
      'Usage: dart run tool/generate_gothic_animation_buffers.dart [--check]',
    );
    stdout.writeln(
      'Regenerates AVARRA Gothic animation buffers and glTF clip metadata.',
    );
    return;
  }
  final unknownArguments = arguments
      .where((argument) => argument != '--check')
      .toList(growable: false);
  if (unknownArguments.isNotEmpty) {
    throw ArgumentError('Unknown arguments: ${unknownArguments.join(', ')}');
  }
  final checkOnly = arguments.contains('--check');
  final repositoryRoot = _findRepositoryRoot();
  _writeAssetCopies(
    repositoryRoot,
    fileName: 'AshenVanguardAnimation.bin',
    gltfFileName: 'AshenVanguard.gltf',
    values: _ashenVanguardAnimationValues(),
    rootNodeIndex: 5,
    rootChildren: const [0, 1, 2, 3, 4],
    clips: const [
      _AnimationClip('Idle', 1.6),
      _AnimationClip('Run', 0.6),
      _AnimationClip('Attack', 0.6),
      _AnimationClip('Dodge', 0.18),
    ],
    targets: const [
      _AnimationTarget(5, 'translation', 'VEC3'),
      _AnimationTarget(5, 'rotation', 'VEC4'),
      _AnimationTarget(4, 'rotation', 'VEC4'),
    ],
    checkOnly: checkOnly,
  );
  _writeAssetCopies(
    repositoryRoot,
    fileName: 'HollowWardenAnimation.bin',
    gltfFileName: 'HollowWarden.gltf',
    values: _hollowWardenAnimationValues(),
    rootNodeIndex: 6,
    rootChildren: const [0, 1, 2, 3, 4, 5],
    clips: const [
      _AnimationClip('Idle', 1.6),
      _AnimationClip('Run', 0.6),
      _AnimationClip('Attack', 0.65),
      _AnimationClip('Hit', 0.35),
      _AnimationClip('Death', 0.9),
    ],
    targets: const [
      _AnimationTarget(6, 'translation', 'VEC3'),
      _AnimationTarget(6, 'rotation', 'VEC4'),
      _AnimationTarget(2, 'rotation', 'VEC4'),
      _AnimationTarget(3, 'rotation', 'VEC4'),
    ],
    checkOnly: checkOnly,
  );
}

List<double> _ashenVanguardAnimationValues() {
  return [
    ..._ashenClip(
      times: const [0, 0.5333333, 1.0666667, 1.6],
      rootTranslations: const [
        [0, 0, 0],
        [0, 0.04, 0],
        [0, -0.025, 0],
        [0, 0, 0],
      ],
      rootRotations: [_qz(0), _qz(1.5), _qz(-1.5), _qz(0)],
      swordRotations: [_qz(45), _qz(48), _qz(42), _qz(45)],
    ),
    ..._ashenClip(
      times: const [0, 0.2, 0.4, 0.6],
      rootTranslations: const [
        [0, 0, 0],
        [0, 0.09, -0.025],
        [0, -0.045, 0.025],
        [0, 0, 0],
      ],
      rootRotations: [_qz(-4), _qz(4), _qz(-4), _qz(-4)],
      swordRotations: [_qz(25), _qz(65), _qz(25), _qz(25)],
    ),
    ..._ashenClip(
      times: const [0, 0.18, 0.35, 0.6],
      rootTranslations: const [
        [0, 0, 0],
        [0, -0.03, -0.08],
        [0, 0.05, 0.06],
        [0, 0, 0],
      ],
      rootRotations: [_qy(0), _qy(-8), _qy(12), _qy(0)],
      swordRotations: [_qz(45), _qz(-65), _qz(100), _qz(45)],
    ),
    ..._ashenClip(
      times: const [0, 0.045, 0.115, 0.18],
      rootTranslations: const [
        [0, 0, 0],
        [0, -0.16, -0.14],
        [0, -0.1, 0.06],
        [0, 0, 0],
      ],
      rootRotations: [_qx(0), _qx(-18), _qx(-10), _qx(0)],
      swordRotations: [_qz(45), _qz(10), _qz(25), _qz(45)],
    ),
  ];
}

List<double> _ashenClip({
  required List<double> times,
  required List<List<double>> rootTranslations,
  required List<List<double>> rootRotations,
  required List<List<double>> swordRotations,
}) {
  return [
    ...times,
    ...rootTranslations.expand((value) => value),
    ...rootRotations.expand((value) => value),
    ...swordRotations.expand((value) => value),
  ];
}

List<double> _hollowWardenAnimationValues() {
  return [
    ..._wardenClip(
      times: const [0, 0.5333333, 1.0666667, 1.6],
      rootTranslations: const [
        [0, 0, 0],
        [0, 0.05, 0],
        [0, -0.035, 0],
        [0, 0, 0],
      ],
      rootRotations: [_qz(0), _qz(2), _qz(-2), _qz(0)],
      leftArmRotations: [_qz(30), _qz(35), _qz(25), _qz(30)],
      rightArmRotations: [_qz(-30), _qz(-25), _qz(-35), _qz(-30)],
    ),
    ..._wardenClip(
      times: const [0, 0.2, 0.4, 0.6],
      rootTranslations: const [
        [0, 0, 0],
        [0, 0.14, -0.04],
        [0, -0.06, 0.04],
        [0, 0, 0],
      ],
      rootRotations: [_qz(-5), _qz(5), _qz(-5), _qz(-5)],
      leftArmRotations: [_qz(55), _qz(-20), _qz(55), _qz(55)],
      rightArmRotations: [_qz(-20), _qz(-55), _qz(-20), _qz(-20)],
    ),
    ..._wardenClip(
      times: const [0, 0.2, 0.42, 0.65],
      rootTranslations: const [
        [0, 0, 0],
        [0, -0.05, -0.1],
        [0, 0.07, 0.08],
        [0, 0, 0],
      ],
      rootRotations: [_qy(0), _qy(-12), _qy(16), _qy(0)],
      leftArmRotations: [_qz(30), _qz(-60), _qz(85), _qz(30)],
      rightArmRotations: [_qz(-30), _qz(60), _qz(-85), _qz(-30)],
    ),
    ..._wardenClip(
      times: const [0, 0.1, 0.22, 0.35],
      rootTranslations: const [
        [0, 0, 0],
        [-0.18, 0, 0],
        [0.12, 0, 0],
        [0, 0, 0],
      ],
      rootRotations: [_qz(0), _qz(-14), _qz(9), _qz(0)],
      leftArmRotations: [_qz(30), _qz(12), _qz(45), _qz(30)],
      rightArmRotations: [_qz(-30), _qz(-48), _qz(-12), _qz(-30)],
    ),
    ..._wardenClip(
      times: const [0, 0.3, 0.6, 0.9],
      rootTranslations: const [
        [0, 0, 0],
        [0, -0.08, 0.04],
        [0.12, -0.28, 0.08],
        [0.35, -0.52, 0.12],
      ],
      rootRotations: [_qz(0), _qz(20), _qz(55), _qz(88)],
      leftArmRotations: [_qz(30), _qz(48), _qz(70), _qz(85)],
      rightArmRotations: [_qz(-30), _qz(-12), _qz(20), _qz(55)],
    ),
  ];
}

List<double> _wardenClip({
  required List<double> times,
  required List<List<double>> rootTranslations,
  required List<List<double>> rootRotations,
  required List<List<double>> leftArmRotations,
  required List<List<double>> rightArmRotations,
}) {
  return [
    ...times,
    ...rootTranslations.expand((value) => value),
    ...rootRotations.expand((value) => value),
    ...leftArmRotations.expand((value) => value),
    ...rightArmRotations.expand((value) => value),
  ];
}

List<double> _qy(double degrees) {
  final halfRadians = degrees * math.pi / 360;
  return [0, math.sin(halfRadians), 0, math.cos(halfRadians)];
}

List<double> _qx(double degrees) {
  final halfRadians = degrees * math.pi / 360;
  return [math.sin(halfRadians), 0, 0, math.cos(halfRadians)];
}

List<double> _qz(double degrees) {
  final halfRadians = degrees * math.pi / 360;
  return [0, 0, math.sin(halfRadians), math.cos(halfRadians)];
}

void _writeAssetCopies(
  Directory repositoryRoot, {
  required String fileName,
  required String gltfFileName,
  required List<double> values,
  required int rootNodeIndex,
  required List<int> rootChildren,
  required List<_AnimationClip> clips,
  required List<_AnimationTarget> targets,
  required bool checkOnly,
}) {
  final bytes = ByteData(values.length * Float32List.bytesPerElement);
  for (var index = 0; index < values.length; index += 1) {
    bytes.setFloat32(
      index * Float32List.bytesPerElement,
      values[index],
      Endian.little,
    );
  }
  final generatedByteLength = bytes.lengthInBytes;
  final generatedBytes = bytes.buffer.asUint8List();
  for (final app in const ['avarra_game', 'avarra_forge']) {
    final output = File(
      '${repositoryRoot.path}${Platform.pathSeparator}apps'
      '${Platform.pathSeparator}$app${Platform.pathSeparator}assets'
      '${Platform.pathSeparator}models${Platform.pathSeparator}gothic'
      '${Platform.pathSeparator}$fileName',
    );
    final gltf = File(
      '${output.parent.path}${Platform.pathSeparator}$gltfFileName',
    );
    final document =
        jsonDecode(gltf.readAsStringSync()) as Map<String, dynamic>;
    _installAnimationMetadata(
      document,
      animationBufferUri: fileName,
      animationBufferByteLength: generatedByteLength,
      rootNodeIndex: rootNodeIndex,
      rootChildren: rootChildren,
      clips: clips,
      targets: targets,
    );
    final generatedGltf =
        '${const JsonEncoder.withIndent('  ').convert(document)}\n';
    if (checkOnly) {
      if (!output.existsSync() ||
          !_sameBytes(output.readAsBytesSync(), generatedBytes)) {
        throw StateError(
          '${output.path} is stale. Run the generator without --check.',
        );
      }
      if (gltf.readAsStringSync() != generatedGltf) {
        throw StateError(
          '${gltf.path} is stale. Run the generator without --check.',
        );
      }
      stdout.writeln('Verified ${output.path} and ${clips.length} glTF clips');
      continue;
    }
    output.writeAsBytesSync(generatedBytes, flush: true);
    gltf.writeAsStringSync(generatedGltf, flush: true);
    stdout
      ..writeln('Wrote ${output.path} (${bytes.lengthInBytes} bytes)')
      ..writeln('Updated ${gltf.path} with ${clips.length} clips');
  }
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

void _installAnimationMetadata(
  Map<String, dynamic> document, {
  required String animationBufferUri,
  required int animationBufferByteLength,
  required int rootNodeIndex,
  required List<int> rootChildren,
  required List<_AnimationClip> clips,
  required List<_AnimationTarget> targets,
}) {
  final buffers = (document['buffers'] as List).take(1).toList();
  buffers.add({
    'byteLength': animationBufferByteLength,
    'uri': animationBufferUri,
  });
  document['buffers'] = buffers;

  final bufferViews = (document['bufferViews'] as List).take(5).toList();
  final accessors = (document['accessors'] as List).take(5).toList();
  final animations = <Map<String, Object?>>[];
  var byteOffset = 0;
  for (final clip in clips) {
    final timeAccessor = accessors.length;
    bufferViews.add({'buffer': 1, 'byteLength': 16, 'byteOffset': byteOffset});
    accessors.add({
      'bufferView': timeAccessor,
      'componentType': 5126,
      'count': 4,
      'max': [clip.duration],
      'min': [0],
      'type': 'SCALAR',
    });
    byteOffset += 16;

    final samplers = <Map<String, Object?>>[];
    final channels = <Map<String, Object?>>[];
    for (final target in targets) {
      final outputAccessor = accessors.length;
      final byteLength = target.type == 'VEC3' ? 48 : 64;
      bufferViews.add({
        'buffer': 1,
        'byteLength': byteLength,
        'byteOffset': byteOffset,
      });
      accessors.add({
        'bufferView': outputAccessor,
        'componentType': 5126,
        'count': 4,
        'type': target.type,
      });
      byteOffset += byteLength;
      final samplerIndex = samplers.length;
      samplers.add({
        'input': timeAccessor,
        'interpolation': 'LINEAR',
        'output': outputAccessor,
      });
      channels.add({
        'sampler': samplerIndex,
        'target': {'node': target.node, 'path': target.path},
      });
    }
    animations.add({
      'name': clip.name,
      'samplers': samplers,
      'channels': channels,
    });
  }
  if (byteOffset != animationBufferByteLength) {
    throw StateError(
      '$animationBufferUri metadata covers $byteOffset bytes; '
      'expected $animationBufferByteLength.',
    );
  }
  document
    ..['bufferViews'] = bufferViews
    ..['accessors'] = accessors
    ..['animations'] = animations;

  final nodes = (document['nodes'] as List).take(rootNodeIndex).toList();
  nodes.add({'name': 'CharacterRoot', 'children': rootChildren});
  document
    ..['nodes'] = nodes
    ..['scenes'] = [
      {
        'nodes': [rootNodeIndex],
      },
    ]
    ..['scene'] = 0;
}

final class _AnimationClip {
  const _AnimationClip(this.name, this.duration);

  final String name;
  final double duration;
}

final class _AnimationTarget {
  const _AnimationTarget(this.node, this.path, this.type);

  final int node;
  final String path;
  final String type;
}

Directory _findRepositoryRoot() {
  var candidate = Directory.current.absolute;
  while (true) {
    if (File(
      '${candidate.path}${Platform.pathSeparator}apps'
      '${Platform.pathSeparator}avarra_game${Platform.pathSeparator}pubspec.yaml',
    ).existsSync()) {
      return candidate;
    }
    final parent = candidate.parent;
    if (parent.path == candidate.path) {
      throw StateError('Could not locate the AVARRA repository root.');
    }
    candidate = parent;
  }
}
