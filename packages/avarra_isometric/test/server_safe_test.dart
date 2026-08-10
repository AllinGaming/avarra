import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

void main() {
  test(
    'avarra_isometric remains free of Flutter and renderer dependencies',
    () async {
      final libraryUri = await Isolate.resolvePackageUri(
        Uri.parse('package:avarra_isometric/avarra_isometric.dart'),
      );
      final packageRoot = File.fromUri(libraryUri!).parent.parent;
      final pubspec = File(
        '${packageRoot.path}${Platform.pathSeparator}pubspec.yaml',
      ).readAsStringSync();

      expect(pubspec, isNot(contains('sdk: flutter')));
      expect(pubspec, isNot(contains('thermion')));
    },
  );
}
