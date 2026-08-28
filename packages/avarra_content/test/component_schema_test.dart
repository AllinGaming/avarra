import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_core/avarra_core.dart';
import 'package:test/test.dart';

void main() {
  final registry = ComponentSchemaRegistry.builtIn();

  test(
    'built-in schemas are machine-readable and deterministically ordered',
    () {
      expect(registry.contentSchemaVersion, currentContentSchemaVersion);
      expect(
        registry.schemas.map((schema) => schema.type),
        orderedEquals([
          AvarraComponentType.guardianArchetype,
          AvarraComponentType.guardianArenaHazard,
          AvarraComponentType.guardianBehavior,
          AvarraComponentType.guardianBoss,
          AvarraComponentType.characterController,
          AvarraComponentType.basicAttack,
          AvarraComponentType.health,
          AvarraComponentType.interactable,
          AvarraComponentType.setPersistentFlagOnInteract,
          AvarraComponentType.isometricOccluder,
          AvarraComponentType.isometricOcclusionTarget,
          AvarraComponentType.collectibleItem,
          AvarraComponentType.playerPowerReward,
          AvarraComponentType.objective,
          AvarraComponentType.objectiveGate,
          AvarraComponentType.itemTurnIn,
          AvarraComponentType.persistentFlags,
          AvarraComponentType.physicsCollider,
          AvarraComponentType.playerControlled,
          AvarraComponentType.renderableReference,
          AvarraComponentType.missionNarrative,
          AvarraComponentType.objectiveMilestoneNarrative,
          AvarraComponentType.transform,
        ]),
      );
      expect(
        registry
            .schemaFor(AvarraComponentType.transform)!
            .fields
            .map((field) => field.name),
        orderedEquals(['position', 'rotation', 'scale']),
      );
    },
  );

  test('decodes valid component data into typed definitions', () {
    final transform = registry.decode(AvarraComponentType.transform, {
      'schemaVersion': 1,
      'position': [1, 2.5, 3],
      'rotation': [0, 0, 0, 1],
      'scale': [1, 2, 1],
    });
    final renderable = registry.decode(
      AvarraComponentType.renderableReference,
      {'schemaVersion': 1, 'assetId': '01890f47-e8b8-7a68-9000-000000000001'},
    );

    expect(transform, isA<TransformDefinition>());
    expect(
      (transform as TransformDefinition).position,
      const ContentVector3(1, 2.5, 3),
    );
    expect(
      (renderable as RenderableReferenceDefinition).assetId.value,
      '01890f47-e8b8-7a68-9000-000000000001',
    );
  });

  test(
    'exposes editor metadata, creates defaults, and replaces typed fields',
    () {
      final colliderSchema = registry.schemaFor(
        AvarraComponentType.physicsCollider,
      )!;
      expect(colliderSchema.label, 'Physics Collider');
      expect(
        colliderSchema.requiredComponentTypes,
        contains(AvarraComponentType.transform),
      );
      expect(
        colliderSchema.fields
            .singleWhere((field) => field.name == 'bodyKind')
            .defaultValue,
        'static',
      );

      final interactable = registry.createDefault(
        AvarraComponentType.interactable,
      );
      expect(interactable, isA<InteractableDefinition>());
      final edited = registry.replaceField(interactable, 'range', 4.5);
      expect((edited as InteractableDefinition).range, 4.5);
      expect(
        () => registry.replaceField(interactable, 'range', 0),
        _throwsCode(ContentErrorCodes.invalidComponentData),
      );
      expect(
        () => registry.createDefault(AvarraComponentType.renderableReference),
        _throwsCode(ContentErrorCodes.invalidComponentData),
      );
    },
  );

  test('decodes Stage 5 physics and gameplay components', () {
    final collider = registry.decode(AvarraComponentType.physicsCollider, {
      'schemaVersion': 1,
      'halfExtents': [0.4, 0.5, 0.6],
      'bodyKind': 'character',
      'isSensor': false,
    });
    final controller = registry.decode(
      AvarraComponentType.characterController,
      {
        'schemaVersion': 1,
        'moveSpeed': 2.5,
        'skinWidth': 0.03,
        'arrivalTolerance': 0.08,
      },
    );
    final interactable = registry.decode(AvarraComponentType.interactable, {
      'schemaVersion': 1,
      'label': 'Console',
      'range': 2.4,
    });

    expect(collider, isA<PhysicsColliderDefinition>());
    expect(
      (collider as PhysicsColliderDefinition).bodyKind,
      ContentPhysicsBodyKind.character,
    );
    expect(controller, isA<CharacterControllerDefinition>());
    expect(interactable, isA<InteractableDefinition>());
  });

  test('keeps content schema v1 readable but excludes v2 components', () {
    expect(() => registry.requireContentSchemaVersion(1), returnsNormally);
    expect(
      () => registry.decode(AvarraComponentType.playerControlled, {
        'schemaVersion': 1,
      }, contentSchemaVersion: 1),
      _throwsCode(ContentErrorCodes.unknownComponentType),
    );
  });

  test('decodes Stage 7 persistent authored defaults', () {
    final persistent = registry.decode(AvarraComponentType.persistentFlags, {
      'schemaVersion': 1,
      'flags': {'activated': false, 'opened': true},
    });

    expect(persistent, isA<PersistentFlagsDefinition>());
    expect((persistent as PersistentFlagsDefinition).flags, {
      'activated': false,
      'opened': true,
    });
    expect(
      () => registry.decode(AvarraComponentType.persistentFlags, {
        'schemaVersion': 1,
        'flags': {'Invalid Key': true},
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
    expect(
      () => registry.decode(AvarraComponentType.persistentFlags, {
        'schemaVersion': 1,
        'flags': {'activated': false},
      }, contentSchemaVersion: 2),
      _throwsCode(ContentErrorCodes.unknownComponentType),
    );
  });

  test('decodes a typed persistent interaction effect in content v4', () {
    final effect = registry.decode(
      AvarraComponentType.setPersistentFlagOnInteract,
      {'schemaVersion': 1, 'flagKey': 'console.activated', 'value': true},
    );

    expect(effect, isA<SetPersistentFlagOnInteractDefinition>());
    expect(
      (effect as SetPersistentFlagOnInteractDefinition).flagKey,
      'console.activated',
    );
    expect(effect.value, isTrue);
    expect(
      () => registry.decode(AvarraComponentType.setPersistentFlagOnInteract, {
        'schemaVersion': 1,
        'flagKey': 'Invalid Key',
        'value': true,
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
    expect(
      () => registry.decode(AvarraComponentType.setPersistentFlagOnInteract, {
        'schemaVersion': 1,
        'flagKey': 'activated',
        'value': true,
      }, contentSchemaVersion: 3),
      _throwsCode(ContentErrorCodes.unknownComponentType),
    );
  });

  test('decodes authored health and basic attack in content v5', () {
    final health = registry.decode(AvarraComponentType.health, {
      'schemaVersion': 1,
      'maximumHealth': 80,
    });
    final attack = registry.decode(AvarraComponentType.basicAttack, {
      'schemaVersion': 1,
      'damage': 12,
      'range': 2.25,
      'cooldownSeconds': 0.5,
    });

    expect((health as HealthDefinition).maximumHealth, 80);
    expect((attack as BasicAttackDefinition).damage, 12);
    expect(attack.range, 2.25);
    expect(attack.cooldownSeconds, 0.5);
    expect(
      () => registry.decode(AvarraComponentType.health, {
        'schemaVersion': 1,
        'maximumHealth': 0,
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
    expect(
      () => registry.decode(AvarraComponentType.basicAttack, {
        'schemaVersion': 1,
        'damage': 12,
        'range': 2.25,
        'cooldownSeconds': 0.5,
      }, contentSchemaVersion: 4),
      _throwsCode(ContentErrorCodes.unknownComponentType),
    );
  });

  test('decodes collectible and turn-in contracts in content v8', () {
    final collectible = registry.decode(AvarraComponentType.collectibleItem, {
      'schemaVersion': 1,
      'itemId': 'relay.core',
      'itemLabel': 'Relay Core',
      'collectedFlagKey': 'collected',
      'guardedByEntityId': '01890f47-e8b8-7a68-8000-000000000009',
    });
    final turnIn = registry.decode(AvarraComponentType.itemTurnIn, {
      'schemaVersion': 1,
      'requiredItemId': 'relay.core',
      'completionFlagKey': 'signal.transmitted',
      'completionLabel': 'Signal transmitted',
    });

    expect((collectible as CollectibleItemDefinition).itemId, 'relay.core');
    expect(collectible.itemLabel, 'Relay Core');
    expect(collectible.collectedFlagKey, 'collected');
    expect(collectible.guardedByEntityId.value, endsWith('0009'));
    expect((turnIn as ItemTurnInDefinition).requiredItemId, 'relay.core');
    expect(turnIn.completionFlagKey, 'signal.transmitted');
    expect(turnIn.completionLabel, 'Signal transmitted');
    expect(
      () => registry.decode(AvarraComponentType.collectibleItem, {
        'schemaVersion': 1,
        'itemId': 'Invalid Item',
        'itemLabel': 'Relay Core',
        'collectedFlagKey': 'collected',
        'guardedByEntityId': '01890f47-e8b8-7a68-8000-000000000009',
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
    expect(
      () => registry.decode(AvarraComponentType.itemTurnIn, {
        'schemaVersion': 1,
        'requiredItemId': 'relay.core',
        'completionFlagKey': 'signal.transmitted',
        'completionLabel': 'Signal transmitted',
      }, contentSchemaVersion: 7),
      _throwsCode(ContentErrorCodes.unknownComponentType),
    );
  });

  test('decodes authored mission narrative only in content v9', () {
    final narrative = registry.decode(AvarraComponentType.missionNarrative, {
      'schemaVersion': 1,
      'title': 'Emberfall Oath',
      'openingText': 'Defeat the warden and reclaim the shard.',
      'returnText': 'Carry the shard to the relay shrine.',
      'completionText': 'The relay burns again.',
    });

    expect(narrative, isA<MissionNarrativeDefinition>());
    expect((narrative as MissionNarrativeDefinition).title, 'Emberfall Oath');
    expect(narrative.returnText, 'Carry the shard to the relay shrine.');
    expect(
      () => registry.decode(AvarraComponentType.missionNarrative, {
        'schemaVersion': 1,
        'title': 'Emberfall Oath',
        'openingText': 'Defeat the warden.',
        'returnText': 'Return to the shrine.',
        'completionText': 'The relay burns again.',
      }, contentSchemaVersion: 8),
      _throwsCode(ContentErrorCodes.unknownComponentType),
    );
    expect(
      () => registry.decode(AvarraComponentType.missionNarrative, {
        'schemaVersion': 1,
        'title': 'Emberfall Oath',
        'openingText': '   ',
        'returnText': 'Return to the shrine.',
        'completionText': 'The relay burns again.',
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
  });

  test('decodes objective milestone narrative only in content v12', () {
    final narrative = registry
        .decode(AvarraComponentType.objectiveMilestoneNarrative, {
          'schemaVersion': 1,
          'completionText': 'A buried ember answers beneath the ash.',
        });

    expect(narrative, isA<ObjectiveMilestoneNarrativeDefinition>());
    expect(
      (narrative as ObjectiveMilestoneNarrativeDefinition).completionText,
      'A buried ember answers beneath the ash.',
    );
    expect(
      () => registry.decode(AvarraComponentType.objectiveMilestoneNarrative, {
        'schemaVersion': 1,
        'completionText': 'A buried ember answers beneath the ash.',
      }, contentSchemaVersion: 11),
      _throwsCode(ContentErrorCodes.unknownComponentType),
    );
    expect(
      () => registry.decode(AvarraComponentType.objectiveMilestoneNarrative, {
        'schemaVersion': 1,
        'completionText': '   ',
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
  });

  test('decodes authored guardian behavior in content v6', () {
    final behavior = registry.decode(AvarraComponentType.guardianBehavior, {
      'schemaVersion': 1,
      'perceptionRange': 4,
      'leashRange': 6,
    });

    expect((behavior as GuardianBehaviorDefinition).perceptionRange, 4);
    expect(behavior.leashRange, 6);
    expect(
      () => registry.decode(AvarraComponentType.guardianBehavior, {
        'schemaVersion': 1,
        'perceptionRange': 6,
        'leashRange': 4,
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
    expect(
      () => registry.decode(AvarraComponentType.guardianBehavior, {
        'schemaVersion': 1,
        'perceptionRange': 4,
        'leashRange': 6,
      }, contentSchemaVersion: 5),
      _throwsCode(ContentErrorCodes.unknownComponentType),
    );
  });

  test('decodes bounded Guardian archetypes only in content v13', () {
    final archetype = registry.decode(AvarraComponentType.guardianArchetype, {
      'schemaVersion': 1,
      'displayName': 'Rift-Touched Reaver',
      'role': 'reaver',
      'eliteModifier': 'riftTouched',
    });

    expect(archetype, isA<GuardianArchetypeDefinition>());
    expect(
      (archetype as GuardianArchetypeDefinition).role,
      GuardianArchetypeRole.reaver,
    );
    expect(
      archetype.eliteModifier,
      GuardianEliteModifierDefinition.riftTouched,
    );
    expect(
      () => registry.decode(AvarraComponentType.guardianArchetype, {
        'schemaVersion': 1,
        'displayName': 'Rift-Touched Reaver',
        'role': 'reaver',
        'eliteModifier': 'riftTouched',
      }, contentSchemaVersion: 12),
      _throwsCode(ContentErrorCodes.unknownComponentType),
    );
    expect(
      () => registry.decode(AvarraComponentType.guardianArchetype, {
        'schemaVersion': 1,
        'displayName': 'Unknown Horror',
        'role': 'summoner',
        'eliteModifier': 'none',
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
  });
  test(
    'decodes authored boss and passive power reward only in content v10',
    () {
      final boss = registry.decode(AvarraComponentType.guardianBoss, {
        'schemaVersion': 1,
        'displayName': 'Vharos, Ashen Castellan',
        'phaseTwoHealthFraction': 0.67,
        'phaseThreeHealthFraction': 0.34,
        'meleeRange': 1.15,
        'sweepRange': 2.6,
        'sweepHalfAngleDegrees': 55,
        'eruptionRadius': 0.9,
        'engageText': 'The Castellan wakes.',
        'phaseTwoText': 'The ash begins to turn.',
        'phaseThreeText': 'The chamber starts to burn.',
        'defeatText': 'The Castellan falls.',
      });
      final reward = registry.decode(AvarraComponentType.playerPowerReward, {
        'schemaVersion': 1,
        'maximumHealthBonus': 25,
      });

      expect((boss as GuardianBossDefinition).displayName, contains('Vharos'));
      expect(boss.phaseThreeHealthFraction, 0.34);
      expect((reward as PlayerPowerRewardDefinition).maximumHealthBonus, 25);
      expect(
        () => registry.decode(AvarraComponentType.guardianBoss, {
          'schemaVersion': 1,
          'displayName': 'Vharos',
          'phaseTwoHealthFraction': 0.4,
          'phaseThreeHealthFraction': 0.7,
          'meleeRange': 1,
          'sweepRange': 2,
          'sweepHalfAngleDegrees': 55,
          'eruptionRadius': 1,
          'engageText': 'Wake.',
          'phaseTwoText': 'Turn.',
          'phaseThreeText': 'Burn.',
          'defeatText': 'Fall.',
        }),
        _throwsCode(ContentErrorCodes.invalidComponentData),
      );
      expect(
        () => registry.decode(AvarraComponentType.playerPowerReward, {
          'schemaVersion': 1,
          'maximumHealthBonus': 25,
        }, contentSchemaVersion: 9),
        _throwsCode(ContentErrorCodes.unknownComponentType),
      );
    },
  );

  test('decodes ordered Guardian arena hazards only in content v11', () {
    final hazard = registry.decode(AvarraComponentType.guardianArenaHazard, {
      'schemaVersion': 1,
      'innerSafeRadius': 0.9,
      'outerRadius': 3.2,
    });

    expect(hazard, isA<GuardianArenaHazardDefinition>());
    expect((hazard as GuardianArenaHazardDefinition).innerSafeRadius, 0.9);
    expect(hazard.outerRadius, 3.2);
    expect(
      () => registry.decode(AvarraComponentType.guardianArenaHazard, {
        'schemaVersion': 1,
        'innerSafeRadius': 2,
        'outerRadius': 1,
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
    expect(
      () => registry.decode(AvarraComponentType.guardianArenaHazard, {
        'schemaVersion': 1,
        'innerSafeRadius': 0.9,
        'outerRadius': 3.2,
      }, contentSchemaVersion: 10),
      _throwsCode(ContentErrorCodes.unknownComponentType),
    );
  });

  test('decodes authored objective groups and gates in content v7', () {
    final objective = registry.decode(AvarraComponentType.objective, {
      'schemaVersion': 1,
      'group': 'relay.stabilizers',
    });
    final gate = registry.decode(AvarraComponentType.objectiveGate, {
      'schemaVersion': 1,
      'label': 'Core chamber gate',
      'group': 'relay.stabilizers',
      'requiredCount': 3,
    });

    expect((objective as ObjectiveDefinition).group, 'relay.stabilizers');
    expect((gate as ObjectiveGateDefinition).requiredCount, 3);
    expect(gate.label, 'Core chamber gate');
    expect(
      () => registry.decode(AvarraComponentType.objectiveGate, {
        'schemaVersion': 1,
        'label': 'Core chamber gate',
        'group': 'Invalid Group',
        'requiredCount': 2.5,
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
    expect(
      () => registry.decode(AvarraComponentType.objective, {
        'schemaVersion': 1,
        'group': 'relay.stabilizers',
      }, contentSchemaVersion: 6),
      _throwsCode(ContentErrorCodes.unknownComponentType),
    );
  });

  test('rejects unknown component types', () {
    expect(
      () => registry.decode('community.untrusted', {'schemaVersion': 1}),
      _throwsCode(ContentErrorCodes.unknownComponentType),
    );
  });

  test('rejects unsupported component versions and unknown fields', () {
    expect(
      () => registry.decode(AvarraComponentType.isometricOccluder, {
        'schemaVersion': 2,
      }),
      _throwsCode(ContentErrorCodes.unsupportedComponentSchemaVersion),
    );
    expect(
      () => registry.decode(AvarraComponentType.isometricOccluder, {
        'schemaVersion': 1,
        'injected': true,
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
  });

  test('rejects invalid transform values', () {
    expect(
      () => registry.decode(AvarraComponentType.transform, {
        'schemaVersion': 1,
        'position': [0, 0, 0],
        'rotation': [0, 0, 0, 0],
        'scale': [1, 1, 1],
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
    expect(
      () => registry.decode(AvarraComponentType.transform, {
        'schemaVersion': 1,
        'position': [0, 0, 0],
        'rotation': [0, 0, 0, 1],
        'scale': [1, 0, 1],
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
  });

  test('rejects invalid Stage 5 component values', () {
    expect(
      () => registry.decode(AvarraComponentType.physicsCollider, {
        'schemaVersion': 1,
        'halfExtents': [0, 1, 1],
        'bodyKind': 'static',
        'isSensor': false,
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
    expect(
      () => registry.decode(AvarraComponentType.physicsCollider, {
        'schemaVersion': 1,
        'halfExtents': [1, 1, 1],
        'bodyKind': 'dynamic',
        'isSensor': false,
      }),
      _throwsCode(ContentErrorCodes.invalidComponentData),
    );
  });
}

Matcher _throwsCode(AvarraErrorCode code) {
  return throwsA(
    isA<AvarraException>().having((error) => error.code, 'code', code),
  );
}
