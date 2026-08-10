import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_persistence/avarra_persistence.dart';
import 'package:test/test.dart';

void main() {
  test('atomically replaces and recovers a same-directory save', () async {
    final directory = await Directory.systemTemp.createTemp(
      'avarra-save-store-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = FileSaveStore(directory);
    final saveId = SaveId.parse('01890f47-e8b8-7a68-8000-000000000401');

    await store.writeAtomic(saveId, 'revision-one');
    await store.writeAtomic(saveId, 'revision-two');
    expect(await store.read(saveId), 'revision-two');

    final target = File(
      '${directory.path}${Platform.pathSeparator}${saveId.value}.avsave',
    );
    final backup = File('${target.path}.backup');
    final pending = File('${target.path}.pending');
    await target.rename(backup.path);
    await pending.writeAsString('incomplete');

    expect(await store.read(saveId), 'revision-two');
    expect(await target.exists(), isTrue);
    expect(await backup.exists(), isFalse);
    expect(await pending.exists(), isFalse);
  });
}
