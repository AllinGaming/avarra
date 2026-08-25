import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ashen Vanguard packages the generated dedicated Dodge clip', () {
    final document =
        jsonDecode(
              File(
                'assets/models/gothic/AshenVanguard.gltf',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final animations = (document['animations'] as List)
        .cast<Map<String, dynamic>>();
    final names = [
      for (final animation in animations) animation['name'] as String,
    ];

    expect(names, ['Idle', 'Run', 'Attack', 'Dodge']);
    final animationBuffer = (document['buffers'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((buffer) => buffer['uri'] == 'AshenVanguardAnimation.bin');
    expect(animationBuffer['byteLength'], 768);
    expect(
      File('assets/models/gothic/AshenVanguardAnimation.bin').lengthSync(),
      768,
    );

    final dodge = animations.singleWhere(
      (animation) => animation['name'] == 'Dodge',
    );
    final firstSampler = (dodge['samplers'] as List)
        .cast<Map<String, dynamic>>()
        .first;
    final inputAccessor = (document['accessors'] as List)
        .cast<Map<String, dynamic>>()[firstSampler['input'] as int];
    expect(inputAccessor['max'], [0.18]);
  });
}
