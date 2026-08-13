import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

void main() {
  test('avarra_persistence remains free of Flutter dependencies', () async {
    final libraryUri = await Isolate.resolvePackageUri(
      Uri.parse('package:avarra_persistence/avarra_persistence.dart'),
    );
    final packageRoot = File.fromUri(libraryUri!).parent.parent;
    final source = Directory('${packageRoot.path}${Platform.pathSeparator}lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(source, isNot(contains('package:flutter/')));
    expect(source, isNot(contains('package:thermion')));
  });
}
