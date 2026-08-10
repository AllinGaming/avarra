import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

void main() {
  test(
    'avarra_network remains free of Flutter and renderer dependencies',
    () async {
      final uri = await Isolate.resolvePackageUri(
        Uri.parse('package:avarra_network/avarra_network.dart'),
      );
      final root = File.fromUri(uri!).parent.parent;
      final source = Directory.fromUri(root.uri.resolve('lib/'))
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');
      final pubspec = File(
        '${root.path}${Platform.pathSeparator}pubspec.yaml',
      ).readAsStringSync();

      expect(pubspec, isNot(contains('sdk: flutter')));
      expect(source, isNot(contains('package:flutter/')));
      expect(source, isNot(contains('thermion')));
    },
  );
}
