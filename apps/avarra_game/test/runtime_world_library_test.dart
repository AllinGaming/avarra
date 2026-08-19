import 'dart:convert';
import 'dart:io';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_game/src/runtime_world_library.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late String source;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('avarra-world-library-');
    source = await File('assets/worlds/isometric_proof.avarra').readAsString();
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test(
    'imports a moved export and restores its selection after restart',
    () async {
      final exportedSource = _renameWorld(
        source,
        id: '01890f47-e8b8-7a68-8000-000000000791',
        name: 'Moved Relay Export',
      );
      final exportDirectory = Directory(
        '${root.path}${Platform.pathSeparator}forge-export',
      )..createSync();
      final deliveryDirectory = Directory(
        '${root.path}${Platform.pathSeparator}delivery',
      )..createSync();
      final exported = File(
        '${exportDirectory.path}${Platform.pathSeparator}relay.avarra',
      )..writeAsStringSync(exportedSource);
      final moved = await exported.rename(
        '${deliveryDirectory.path}${Platform.pathSeparator}relay.avarra',
      );
      final catalogDirectory = Directory(
        '${root.path}${Platform.pathSeparator}catalog',
      );
      final library = RuntimeWorldLibrary(
        directory: catalogDirectory,
        assetAvailability: (_) async => true,
      );

      final imported = await library.importFile(moved.path);
      await moved.delete();

      expect(imported.name, 'Moved Relay Export');
      expect(await library.list(), hasLength(1));
      final restarted = RuntimeWorldLibrary(
        directory: catalogDirectory,
        assetAvailability: (_) async => true,
      );
      final selected = await restarted.loadSelected();

      expect(selected?.worldId.value, '01890f47-e8b8-7a68-8000-000000000791');
      expect(selected?.name, 'Moved Relay Export');
      expect(
        const RuntimeWorldLoader()
            .load(WorldPackageCodec().decode(selected!.source))
            .definition
            .name,
        'Moved Relay Export',
      );
      await restarted.clearSelection();
      expect(await restarted.loadSelected(), isNull);
    },
  );

  test('reports every unavailable authored asset path', () async {
    final unavailable = jsonDecode(source) as Map<String, dynamic>;
    final assets = unavailable['assets']! as List<dynamic>;
    (assets.first as Map<String, dynamic>)['path'] =
        'assets/models/missing/Relay.gltf';
    final library = RuntimeWorldLibrary(
      directory: Directory('${root.path}${Platform.pathSeparator}catalog'),
      assetAvailability: (_) async => false,
    );

    await expectLater(
      library.importSource(jsonEncode(unavailable)),
      throwsA(
        isA<AvarraException>()
            .having(
              (error) => error.code,
              'code',
              RuntimeWorldLibraryErrorCodes.assetUnavailable,
            )
            .having((error) => error.context['paths'], 'paths', [
              'assets/models/gothic/AshenVanguard.gltf',
              'assets/models/gothic/Basalt.gltf',
              'assets/models/gothic/CoreGate.gltf',
              'assets/models/gothic/EmberShard.gltf',
              'assets/models/gothic/HollowWarden.gltf',
              'assets/models/gothic/RelayShrine.gltf',
              'assets/models/missing/Relay.gltf',
            ]),
      ),
    );
  });

  test('rejects source beyond the configured import boundary', () async {
    final library = RuntimeWorldLibrary(
      directory: Directory('${root.path}${Platform.pathSeparator}catalog'),
      assetAvailability: (_) async => true,
      maximumSourceBytes: 8,
    );

    await expectLater(
      library.importSource(source),
      throwsA(
        isA<AvarraException>().having(
          (error) => error.code,
          'code',
          RuntimeWorldLibraryErrorCodes.sourceTooLarge,
        ),
      ),
    );
  });

  test('does not let a corrupt catalog entry block valid choices', () async {
    final catalog = Directory('${root.path}${Platform.pathSeparator}catalog')
      ..createSync();
    File(
      '${catalog.path}${Platform.pathSeparator}broken.avarra',
    ).writeAsStringSync('{bad');
    final library = RuntimeWorldLibrary(
      directory: catalog,
      assetAvailability: (_) async => true,
    );

    expect(await library.list(), isEmpty);
  });

  test('imports every valid map in a selected folder independently', () async {
    final delivery = Directory(
      '${root.path}${Platform.pathSeparator}community-maps',
    )..createSync();
    File(
      '${delivery.path}${Platform.pathSeparator}ashfall.avarra',
    ).writeAsStringSync(
      _renameWorld(
        source,
        id: '01890f47-e8b8-7a68-8000-000000000792',
        name: 'Community Ashfall',
      ),
    );
    File(
      '${delivery.path}${Platform.pathSeparator}broken.avarra',
    ).writeAsStringSync('{broken');
    File(
      '${delivery.path}${Platform.pathSeparator}notes.txt',
    ).writeAsStringSync('not a map');
    final library = RuntimeWorldLibrary(
      directory: Directory('${root.path}${Platform.pathSeparator}catalog'),
      assetAvailability: (_) async => true,
    );

    final result = await library.importDirectory(delivery.path);

    expect(result.imported, hasLength(1));
    expect(result.imported.single.name, 'Community Ashfall');
    expect(result.failures, hasLength(1));
    expect(result.failures.single.path, endsWith('broken.avarra'));
    expect(await library.list(), hasLength(1));
    expect((await library.loadSelected())?.name, 'Community Ashfall');
  });
}

String _renameWorld(String source, {required String id, required String name}) {
  final json = jsonDecode(source) as Map<String, dynamic>;
  final world = json['world']! as Map<String, dynamic>;
  world['id'] = id;
  world['name'] = name;
  return jsonEncode(json);
}
