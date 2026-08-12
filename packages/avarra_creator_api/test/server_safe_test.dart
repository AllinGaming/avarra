import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

void main() {
  test('avarra_creator_api remains free of Flutter dependencies', () async {
    final libraryUri = await Isolate.resolvePackageUri(
      Uri.parse('package:avarra_creator_api/avarra_creator_api.dart'),
    );
    final packageRoot = File.fromUri(libraryUri!).parent.parent;
    final pubspec = File(
      '${packageRoot.path}${Platform.pathSeparator}pubspec.yaml',
    ).readAsStringSync();

    expect(pubspec, isNot(contains('sdk: flutter')));
  });
}
