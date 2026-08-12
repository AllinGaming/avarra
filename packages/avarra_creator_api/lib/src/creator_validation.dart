import 'package:avarra_core/avarra_core.dart';
import 'package:avarra_world/avarra_world.dart';

import 'creator_error_codes.dart';

final class CreatorValidationIssue {
  const CreatorValidationIssue({
    required this.code,
    required this.message,
    this.context = const {},
  });

  final AvarraErrorCode code;
  final String message;
  final Map<String, Object?> context;
}

final class CreatorValidationReport {
  CreatorValidationReport(Iterable<CreatorValidationIssue> issues)
    : issues = List.unmodifiable(issues);

  final List<CreatorValidationIssue> issues;

  bool get isValid => issues.isEmpty;

  void throwIfInvalid() {
    if (isValid) {
      return;
    }
    final first = issues.first;
    throw AvarraException(
      code: CreatorErrorCodes.validationFailed,
      message: first.message,
      context: {
        'issueCode': first.code.value,
        'issueCount': issues.length,
        ...first.context,
      },
    );
  }
}

/// Runs the same canonical package checks used by Game and Server.
final class CreatorWorldValidator {
  CreatorWorldValidator({WorldPackageCodec? codec})
    : _codec = codec ?? WorldPackageCodec();

  final WorldPackageCodec _codec;

  CreatorValidationReport validate(
    WorldDefinition world, {
    bool requirePlayableEntry = false,
  }) {
    final issues = <CreatorValidationIssue>[];
    try {
      _codec.decode(_codec.encodeCanonical(world));
    } on AvarraException catch (error) {
      issues.add(
        CreatorValidationIssue(
          code: error.code,
          message: error.message,
          context: error.context,
        ),
      );
    } on Object catch (error) {
      issues.add(
        CreatorValidationIssue(
          code: CreatorErrorCodes.validationFailed,
          message: 'The world cannot be encoded as canonical content.',
          context: {'errorType': error.runtimeType.toString()},
        ),
      );
    }
    if (requirePlayableEntry) {
      issues.addAll(
        const PlayableWorldValidator()
            .validate(world)
            .issues
            .map(
              (issue) => CreatorValidationIssue(
                code: issue.code,
                message: issue.message,
                context: issue.context,
              ),
            ),
      );
    }
    return CreatorValidationReport(issues);
  }
}
