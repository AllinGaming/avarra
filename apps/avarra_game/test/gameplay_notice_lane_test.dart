import 'package:avarra_game/src/gameplay_notice_lane.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects notices in deterministic player-attention order', () {
    GameplayNoticeLaneSlot? select({
      bool boss = false,
      bool powerReward = false,
      bool objective = false,
      bool story = false,
      bool loot = false,
    }) => selectGameplayNoticeLane(
      blocked: false,
      hasBoss: boss,
      hasPowerReward: powerReward,
      hasObjective: objective,
      hasStory: story,
      hasLoot: loot,
    );

    expect(
      select(
        boss: true,
        powerReward: true,
        objective: true,
        story: true,
        loot: true,
      ),
      GameplayNoticeLaneSlot.boss,
    );
    expect(
      select(powerReward: true, objective: true, story: true, loot: true),
      GameplayNoticeLaneSlot.powerReward,
    );
    expect(
      select(objective: true, story: true, loot: true),
      GameplayNoticeLaneSlot.objective,
    );
    expect(select(story: true, loot: true), GameplayNoticeLaneSlot.story);
    expect(select(loot: true), GameplayNoticeLaneSlot.loot);
    expect(select(), isNull);
  });

  test('blocking overlays suspend notices without changing their priority', () {
    expect(
      selectGameplayNoticeLane(
        blocked: true,
        hasBoss: true,
        hasPowerReward: true,
        hasObjective: true,
        hasStory: true,
        hasLoot: true,
      ),
      isNull,
    );
    expect(
      () => selectGameplayNoticeLane(
        blocked: false,
        hasBoss: false,
        hasPowerReward: true,
        hasObjective: false,
        hasStory: false,
        hasLoot: false,
      ),
      throwsArgumentError,
    );
  });
}
