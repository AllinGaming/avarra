import 'dart:math' as math;

import 'package:avarra_world/avarra_world.dart';
import 'package:flutter/material.dart';

/// One authoritative mission-phase transition presented to the local player.
final class GameplayStoryNotice {
  const GameplayStoryNotice({required this.sequence, required this.beat})
    : assert(sequence > 0);

  final int sequence;
  final AuthoredMissionNarrative beat;
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
                            Text(
                              _phaseLabel(current.phase),
                              key: const Key('quest_journal_phase'),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: _phaseColor(current.phase),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
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
                          Text(
                            _phaseLabel(notice.beat.phase),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: _phaseColor(notice.beat.phase),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.8,
                                ),
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
