import 'dart:convert';

import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';

import 'creator_error_codes.dart';

const String avarraForgeProjectFormat = 'avarra.forge_project';
const int currentForgeProjectFormatVersion = 1;
const String avarraForgeProjectExtension = '.avarra-forge';

/// Editable Forge source state, intentionally distinct from runtime `.avarra`.
final class ForgeProject {
  const ForgeProject({required this.world});

  final WorldDefinition world;
}

/// Strict versioned codec for the first single-world Forge source document.
final class ForgeProjectCodec {
  ForgeProjectCodec({WorldPackageCodec? worldCodec})
    : _worldCodec = worldCodec ?? WorldPackageCodec();

  final WorldPackageCodec _worldCodec;

  ForgeProject decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw AvarraException(
        code: CreatorErrorCodes.projectMalformed,
        message: 'The Forge project is not valid JSON.',
        context: {'offset': error.offset},
      );
    }
    if (decoded is! Map<String, dynamic>) {
      _malformed('The Forge project root must be an object.');
    }
    final fields = decoded.keys.toSet();
    const expectedFields = {'format', 'projectFormatVersion', 'world'};
    if (fields.length != expectedFields.length ||
        !fields.containsAll(expectedFields)) {
      _malformed(
        'The Forge project contains missing or unknown root fields.',
        context: {
          'fields': fields.toList()..sort(),
          'expectedFields': expectedFields.toList()..sort(),
        },
      );
    }
    if (decoded['format'] != avarraForgeProjectFormat ||
        decoded['projectFormatVersion'] != currentForgeProjectFormatVersion) {
      throw AvarraException(
        code: CreatorErrorCodes.projectFormatUnsupported,
        message: 'The Forge project format is not supported.',
        context: {
          'format': decoded['format'],
          'projectFormatVersion': decoded['projectFormatVersion'],
          'expectedFormat': avarraForgeProjectFormat,
          'expectedProjectFormatVersion': currentForgeProjectFormatVersion,
        },
      );
    }
    final encodedWorld = decoded['world'];
    if (encodedWorld is! Map<String, dynamic>) {
      _malformed('The Forge project world must be an object.');
    }
    return ForgeProject(world: _worldCodec.decode(jsonEncode(encodedWorld)));
  }

  String encodeCanonical(ForgeProject project) {
    final world = jsonDecode(_worldCodec.encodeCanonical(project.world));
    return jsonEncode({
      'format': avarraForgeProjectFormat,
      'projectFormatVersion': currentForgeProjectFormatVersion,
      'world': world,
    });
  }

  Never _malformed(String message, {Map<String, Object?> context = const {}}) {
    throw AvarraException(
      code: CreatorErrorCodes.projectMalformed,
      message: message,
      context: context,
    );
  }
}
