import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('avarra_persistence remains free of Flutter dependencies', () {
    final source = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(source, isNot(contains('package:flutter/')));
    expect(source, isNot(contains('package:thermion')));
  });
}
