import 'dart:io';
import 'dart:isolate';

import 'package:avarra_core/avarra_core.dart';
import 'package:test/test.dart';

void main() {
  test('exposes AVARRA foundation metadata', () {
    expect(avarraProductName, 'AVARRA');
    expect(avarraArchitectureGeneration, 'v8-reviewed');
  });

  test('remains server safe', () async {
    final libraryUri = await Isolate.resolvePackageUri(
      Uri.parse('package:avarra_core/avarra_core.dart'),
    );
    final packageRoot = File.fromUri(libraryUri!).parent.parent;
    final pubspec = File(
      '${packageRoot.path}${Platform.pathSeparator}pubspec.yaml',
    ).readAsStringSync();

    expect(pubspec, isNot(contains('sdk: flutter')));
  });
}
