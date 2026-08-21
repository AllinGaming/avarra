import 'dart:io';

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_creator_api/avarra_creator_api.dart';
import 'package:avarra_forge/src/forge_palette.dart';
import 'package:avarra_forge/src/forge_sample_world.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1 || arguments.single.trim().isEmpty) {
    stderr.writeln(
      'Usage: dart run bin/export_profiled_mission.dart <output.avarra>',
    );
    exitCode = 64;
    return;
  }

  final world = createForgeSampleWorld();
  final profile = forgeGuardianMissionProfileById('champion')!;
  final settings = profile.applyTo(
    const ForgeGuardianMissionSettings(
      itemLabel: 'Ember shard',
      completionLabel: 'Relay secured',
    ),
  );
  final assets = ForgeGuardianMissionAssets(
    guardianAssetId: forgeHollowWardenAssetId,
    collectibleAssetId: forgeEmberShardAssetId,
    completionConsoleAssetId: forgeRelayShrineAssetId,
  );
  final issue = forgeGuardianMissionTemplateIssue(
    world,
    settings: settings,
    assets: assets,
  );
  if (issue != null) {
    throw StateError('Profiled mission is not exportable: $issue');
  }
  final mission = createForgeGuardianMissionTemplate(
    guardianEntityId: EntityId.generate(),
    collectibleEntityId: EntityId.generate(),
    completionConsoleEntityId: EntityId.generate(),
    assets: assets,
    groundPosition: const ContentVector3(0, 0, 0),
    settings: settings,
  );
  final session = CreatorWorldSession(initialWorld: world);
  session.execute(
    CreatorCommandBatch(
      description: 'Place Champion Gothic guardian mission',
      commands: [
        for (final entity in mission.entities)
          CreateEntityCommand(entity: entity),
      ],
    ),
  );
  final source = session.exportCanonical();
  final output = File(arguments.single);
  await output.parent.create(recursive: true);
  await output.writeAsString(source, flush: true);
  stdout.writeln(
    'Exported ${profile.label} mission with ${mission.entities.length} '
    'role assets to ${output.path}',
  );
}
