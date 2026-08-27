import 'dart:math' as math;

import 'package:avarra_content/avarra_content.dart';
import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';

/// One authoritative mission-phase transition presented to the local player.
final class GameplayStoryNotice {
  const GameplayStoryNotice({required this.sequence, required this.beat})
    : assert(sequence > 0);

  final int sequence;
  final AuthoredMissionNarrative beat;
}

enum GameplayStoryTransitionPresentation { toast, missionCompleteRecap }

/// Resolves one transition beat without losing an intermediate mission's
/// completion epilogue when the active mission advances in the same
/// authoritative state change.
AuthoredMissionNarrative? gameplayStoryBeatForTransition({
  required WorldDefinition definition,
  required AuthoredAdventureProgress previous,
  required AuthoredAdventureProgress current,
}) {
  final activeBeat = authoredMissionNarrative(definition, current);
  if (activeBeat == null) {
    return activeBeat;
  }
  final newlyCompletedTurnInIds = current.completedTurnInEntityIds.difference(
    previous.completedTurnInEntityIds,
  );
  if (newlyCompletedTurnInIds.isEmpty) {
    return activeBeat;
  }
  final completedEntities =
      definition.allEntities
          .where((entity) => newlyCompletedTurnInIds.contains(entity.id))
          .where(
            (entity) =>
                entity.component<ItemTurnInDefinition>() != null &&
                entity.component<MissionNarrativeDefinition>() != null,
          )
          .toList()
        ..sort((left, right) => left.id.value.compareTo(right.id.value));
  if (completedEntities.isEmpty) {
    return activeBeat;
  }
  final bridgedEntities = current.isMissionComplete
      ? completedEntities
            .where((entity) => entity.id != activeBeat.turnInEntityId)
            .toList()
      : completedEntities;
  if (bridgedEntities.isEmpty) {
    return activeBeat;
  }
  final completedText = bridgedEntities
      .map((entity) {
        final narrative = entity.component<MissionNarrativeDefinition>()!;
        return '${narrative.title}: ${narrative.completionText}';
      })
      .join('\n\n');
  return AuthoredMissionNarrative(
    turnInEntityId: activeBeat.turnInEntityId,
    chapterNumber: activeBeat.chapterNumber,
    chapterCount: activeBeat.chapterCount,
    phase: activeBeat.phase,
    title: activeBeat.title,
    text: '$completedText\n\n${activeBeat.text}',
  );
}

/// Chooses a blocking recap only for completion earned after initial state is
/// known. Restored saves and first replicated snapshots keep the non-blocking
/// toast behavior.
GameplayStoryTransitionPresentation gameplayStoryTransitionPresentationFor({
  required AuthoredMissionNarrative beat,
  required bool allowMissionCompleteRecap,
}) {
  if (allowMissionCompleteRecap &&
      beat.phase == AuthoredMissionNarrativePhase.complete) {
    return GameplayStoryTransitionPresentation.missionCompleteRecap;
  }
  return GameplayStoryTransitionPresentation.toast;
}

enum GameplayObjectiveMilestoneKind { objectiveSecured, pathOpened }

/// One presentation-only milestone derived from a confirmed objective change.
final class GameplayObjectiveMilestoneNotice {
  const GameplayObjectiveMilestoneNotice({
    required this.sequence,
    required this.kind,
    required this.title,
    required this.detail,
    this.storyText,
  }) : assert(sequence > 0);

  final int sequence;
  final GameplayObjectiveMilestoneKind kind;
  final String title;
  final String detail;
  final String? storyText;

  String get phaseLabel => switch (kind) {
    GameplayObjectiveMilestoneKind.objectiveSecured => 'OBJECTIVE SECURED',
    GameplayObjectiveMilestoneKind.pathOpened => 'PATH OPENED',
  };
}

/// Derives at most one milestone from two consecutive authoritative states.
///
/// A newly opened gate takes precedence over its completing objective so the
/// player sees the most consequential result of that interaction.
GameplayObjectiveMilestoneNotice? gameplayObjectiveMilestoneNoticeFor({
  required int sequence,
  required WorldDefinition definition,
  required AuthoredObjectiveProgress previous,
  required AuthoredObjectiveProgress current,
}) {
  final newlyCompletedIds = current.completedObjectiveEntityIds.difference(
    previous.completedObjectiveEntityIds,
  );
  final objectiveEntities =
      definition.allEntities
          .where((entity) => newlyCompletedIds.contains(entity.id))
          .toList()
        ..sort((left, right) => left.id.value.compareTo(right.id.value));
  final storyTexts = [
    for (final entity in objectiveEntities)
      if (entity.component<ObjectiveMilestoneNarrativeDefinition>()
          case final narrative?)
        narrative.completionText,
  ];
  final storyText = storyTexts.isEmpty ? null : storyTexts.join(' ');
  final newlyOpenedGateIds = current
      .openedGateEntityIds(definition)
      .difference(previous.openedGateEntityIds(definition));
  if (newlyOpenedGateIds.isNotEmpty) {
    final gateEntities =
        definition.allEntities
            .where((entity) => newlyOpenedGateIds.contains(entity.id))
            .toList()
          ..sort((left, right) => left.id.value.compareTo(right.id.value));
    final gate = gateEntities.first.component<ObjectiveGateDefinition>()!;
    return GameplayObjectiveMilestoneNotice(
      sequence: sequence,
      kind: GameplayObjectiveMilestoneKind.pathOpened,
      title: gate.label,
      storyText: storyText,
      detail:
          'Threshold satisfied Â· '
          '${current.completedCount}/${current.totalCount} objectives complete',
    );
  }

  if (newlyCompletedIds.isEmpty) return null;
  final labels = [
    for (final entity in objectiveEntities)
      entity.component<InteractableDefinition>()?.label ?? entity.id.value,
  ];
  return GameplayObjectiveMilestoneNotice(
    sequence: sequence,
    kind: GameplayObjectiveMilestoneKind.objectiveSecured,
    title: labels.join(' + '),
    storyText: storyText,
    detail:
        'Mission progress Â· '
        '${current.completedCount}/${current.totalCount} objectives complete',
  );
}

/// A short, non-blocking objective banner for earned mission progress.
final class GameplayObjectiveMilestoneToast extends StatefulWidget {
  const GameplayObjectiveMilestoneToast({
    required this.notice,
    this.compact = false,
    this.reducedMotion = false,
    this.onFinished,
    super.key,
  });

  final GameplayObjectiveMilestoneNotice? notice;
  final bool compact;
  final bool reducedMotion;
  final ValueChanged<int>? onFinished;

  @override
  State<GameplayObjectiveMilestoneToast> createState() =>
      _GameplayObjectiveMilestoneToastState();
}

final class _GameplayObjectiveMilestoneToastState
    extends State<GameplayObjectiveMilestoneToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3900),
    )..addStatusListener(_handleStatus);
    if (widget.notice != null) _controller.forward();
  }

  @override
  void didUpdateWidget(GameplayObjectiveMilestoneToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notice?.sequence != widget.notice?.sequence) {
      if (widget.notice == null) {
        _controller.reset();
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  void _handleStatus(AnimationStatus status) {
    final notice = widget.notice;
    if (status == AnimationStatus.completed && notice != null) {
      widget.onFinished?.call(notice.sequence);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    return IgnorePointer(
      key: const Key('gameplay_objective_milestone'),
      child: notice == null
          ? const SizedBox.shrink()
          : Semantics(
              key: const Key('objective_milestone_semantics'),
              liveRegion: true,
              label:
                  '${notice.phaseLabel}: ${notice.title}. '
                  '${notice.storyText == null ? '' : '${notice.storyText} '}'
                  '${notice.detail}',
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final progress = _controller.value;
                  final fadeIn = (progress / 0.11).clamp(0, 1).toDouble();
                  final fadeOut = ((1 - progress) / 0.2).clamp(0, 1).toDouble();
                  final opacity = math.min(fadeIn, fadeOut).toDouble();
                  final easedIn = Curves.easeOutCubic.transform(fadeIn);
                  final scale = widget.reducedMotion
                      ? 1.0
                      : 0.94 + (0.06 * easedIn);
                  final slide = widget.reducedMotion ? 0.0 : 12 * (1 - easedIn);
                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, slide),
                      child: Transform.scale(scale: scale, child: child),
                    ),
                  );
                },
                child: _ObjectiveMilestoneCard(
                  notice: notice,
                  compact: widget.compact,
                ),
              ),
            ),
    );
  }
}

final class _ObjectiveMilestoneCard extends StatelessWidget {
  const _ObjectiveMilestoneCard({required this.notice, required this.compact});

  final GameplayObjectiveMilestoneNotice notice;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (notice.kind) {
      GameplayObjectiveMilestoneKind.objectiveSecured => const Color(
        0xFFFFC66E,
      ),
      GameplayObjectiveMilestoneKind.pathOpened => const Color(0xFFFFE0A0),
    };
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 300 : 460),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xF21A1008), Color(0xE620160D), Color(0xF21A1008)],
          ),
          border: Border.symmetric(
            horizontal: BorderSide(color: color.withValues(alpha: 0.75)),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 26,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 22,
            compact ? 10 : 13,
            compact ? 14 : 22,
            compact ? 11 : 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: Divider(color: color.withValues(alpha: 0.5))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    child: Icon(
                      notice.kind == GameplayObjectiveMilestoneKind.pathOpened
                          ? Icons.lock_open
                          : Icons.diamond_outlined,
                      size: compact ? 15 : 17,
                      color: color,
                    ),
                  ),
                  Expanded(child: Divider(color: color.withValues(alpha: 0.5))),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                notice.phaseLabel,
                key: const Key('objective_milestone_phase'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notice.title,
                key: const Key('objective_milestone_title'),
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFFFF2D7),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              if (notice.storyText case final storyText?) ...[
                Text(
                  storyText,
                  key: const Key('objective_milestone_story'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFEAD8BC),
                    fontStyle: FontStyle.italic,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
              ],
              Text(
                notice.detail,
                key: const Key('objective_milestone_detail'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFD7C7AF),
                  letterSpacing: 0.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diablo-style quest tracker backed by the currently derived authored beat.
final class GameplayQuestJournal extends StatelessWidget {
  const GameplayQuestJournal({
    required this.beat,
    this.compact = false,
    this.guidanceLabel,
    this.guidanceDistanceLabel,
    super.key,
  });

  final AuthoredMissionNarrative? beat;
  final bool compact;
  final String? guidanceLabel;
  final String? guidanceDistanceLabel;

  @override
  Widget build(BuildContext context) {
    final current = beat;
    return IgnorePointer(
      key: const Key('gameplay_quest_journal'),
      child: current == null
          ? const SizedBox.shrink()
          : Semantics(
              key: const Key('quest_journal_semantics'),
              label:
                  '${current.chapterLabel}. '
                  '${_phaseLabel(current.phase)}: ${current.title}. '
                  '${current.text}',
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 300 : 340),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xE615100C),
                    border: Border(
                      left: BorderSide(
                        color: _phaseColor(current.phase),
                        width: 3,
                      ),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x66000000), blurRadius: 14),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 10 : 13,
                      compact ? 8 : 11,
                      compact ? 10 : 13,
                      compact ? 8 : 11,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _phaseIcon(current.phase),
                              size: compact ? 14 : 16,
                              color: _phaseColor(current.phase),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _phaseLabel(current.phase),
                                key: const Key('quest_journal_phase'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: _phaseColor(current.phase),
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.4,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              current.chapterLabel,
                              key: const Key('quest_journal_chapter'),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: const Color(0xFF9F8D78),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.7,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          current.title,
                          key: const Key('quest_journal_title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          current.text,
                          key: const Key('quest_journal_text'),
                          maxLines: compact ? 2 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFFD8CEC0),
                                height: 1.25,
                              ),
                        ),
                        if (guidanceLabel case final guidance?) ...[
                          const SizedBox(height: 7),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(top: 6),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0x447E6A54)),
                              ),
                            ),
                            child: Text(
                              'NEXT · ${guidance.toUpperCase()}'
                              '${guidanceDistanceLabel == null ? '' : ' · ${guidanceDistanceLabel!}'}',
                              key: const Key('quest_journal_guidance'),
                              maxLines: compact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: const Color(0xFFFFC66E),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Animated briefing, return prompt, or epilogue for a confirmed story beat.
final class GameplayStoryToast extends StatefulWidget {
  const GameplayStoryToast({
    required this.notice,
    this.compact = false,
    this.onFinished,
    super.key,
  });

  final GameplayStoryNotice? notice;
  final bool compact;
  final ValueChanged<int>? onFinished;

  @override
  State<GameplayStoryToast> createState() => _GameplayStoryToastState();
}

final class _GameplayStoryToastState extends State<GameplayStoryToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..addStatusListener(_handleStatus);
    if (widget.notice != null) _controller.forward();
  }

  @override
  void didUpdateWidget(GameplayStoryToast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notice?.sequence != widget.notice?.sequence) {
      if (widget.notice == null) {
        _controller.reset();
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  void _handleStatus(AnimationStatus status) {
    final notice = widget.notice;
    if (status == AnimationStatus.completed && notice != null) {
      widget.onFinished?.call(notice.sequence);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    return IgnorePointer(
      key: const Key('gameplay_story_notice'),
      child: notice == null
          ? const SizedBox.shrink()
          : Semantics(
              key: const Key('story_notice_semantics'),
              liveRegion: true,
              label:
                  '${notice.beat.chapterLabel}. '
                  '${_phaseLabel(notice.beat.phase)}: '
                  '${notice.beat.title}. ${notice.beat.text}',
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final progress = _controller.value;
                  final fadeIn = (progress / 0.1).clamp(0, 1).toDouble();
                  final fadeOut = ((1 - progress) / 0.18)
                      .clamp(0, 1)
                      .toDouble();
                  final opacity = math.min(fadeIn, fadeOut).toDouble();
                  final slide =
                      18 * (1 - Curves.easeOutCubic.transform(fadeIn));
                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(slide, 0),
                      child: child,
                    ),
                  );
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: widget.compact ? 300 : 430,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xF21A120C),
                      border: Border.all(color: _phaseColor(notice.beat.phase)),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: _phaseColor(
                            notice.beat.phase,
                          ).withValues(alpha: 0.32),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _phaseLabel(notice.beat.phase),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: _phaseColor(notice.beat.phase),
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.8,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                notice.beat.chapterLabel,
                                key: const Key('story_notice_chapter'),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: const Color(0xFFAE9071),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notice.beat.title,
                            key: const Key('story_notice_title'),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            notice.beat.text,
                            key: const Key('story_notice_text'),
                            maxLines: widget.compact ? 3 : 5,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFFE9DED0),
                                  height: 1.28,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

String _phaseLabel(AuthoredMissionNarrativePhase phase) => switch (phase) {
  AuthoredMissionNarrativePhase.opening => 'QUEST BEGUN',
  AuthoredMissionNarrativePhase.returnToTurnIn => 'RELIC RECOVERED',
  AuthoredMissionNarrativePhase.complete => 'QUEST COMPLETE',
};

Color _phaseColor(AuthoredMissionNarrativePhase phase) => switch (phase) {
  AuthoredMissionNarrativePhase.opening => const Color(0xFFFFB55D),
  AuthoredMissionNarrativePhase.returnToTurnIn => const Color(0xFFFFD36B),
  AuthoredMissionNarrativePhase.complete => const Color(0xFF8ED489),
};

IconData _phaseIcon(AuthoredMissionNarrativePhase phase) => switch (phase) {
  AuthoredMissionNarrativePhase.opening => Icons.outlined_flag,
  AuthoredMissionNarrativePhase.returnToTurnIn => Icons.reply,
  AuthoredMissionNarrativePhase.complete => Icons.auto_awesome,
};
