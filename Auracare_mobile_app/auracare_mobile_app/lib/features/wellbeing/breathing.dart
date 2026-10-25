import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../core/widgets.dart';
import 'breath_haptics.dart';

/// A monotonic, frame-independent clock. Ticker frames only refresh its display.
class BreathingClock {
  Duration duration = const Duration(minutes: 1);
  Duration elapsed = Duration.zero;
  Duration? anchor;
  bool get running => anchor != null;
  bool get complete => elapsed >= duration;
  void update(Duration now) {
    if (anchor == null) return;
    elapsed += now - anchor!;
    anchor = now;
    if (elapsed >= duration) {
      elapsed = duration;
      anchor = null;
    }
  }

  void start(Duration now) {
    if (!complete) anchor = now;
  }

  void pause(Duration now) {
    update(now);
    anchor = null;
  }

  void reset() {
    elapsed = Duration.zero;
    anchor = null;
  }
}

class BreathingSection extends StatefulWidget {
  const BreathingSection({super.key, this.active = true, this.haptics});
  final bool active;
  final BreathHaptics? haptics;
  @override
  State<BreathingSection> createState() => _BreathingSectionState();
}

class _BreathingSectionState extends State<BreathingSection>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        RouteAware,
        AutomaticKeepAliveClientMixin {
  final clock = BreathingClock();
  late final haptics = widget.haptics ?? BreathHaptics();
  bool vibration = false;
  int lastPhase = 0;
  void cue(BreathCue cue) {
    if (vibration && widget.active) unawaited(haptics.cue(cue));
  }

  late final Ticker ticker;
  ModalRoute<dynamic>? route;
  Duration get now => SchedulerBinding.instance.currentSystemFrameTimeStamp;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ticker = createTicker((_) {
      setState(() => clock.update(now));
      if (clock.complete) {
        ticker.stop();
        cue(BreathCue.finish);
      } else {
        final phase =
            clock.elapsed.inMilliseconds ~/ 10000 * 2 +
            (clock.elapsed.inMilliseconds % 10000 >= 4000 ? 1 : 0);
        if (phase != lastPhase) {
          lastPhase = phase;
          cue(phase.isEven ? BreathCue.inhale : BreathCue.exhale);
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ModalRoute.of(context);
    if (route != next) {
      auraRouteObserver.unsubscribe(this);
      route = next;
      if (next != null) auraRouteObserver.subscribe(this, next);
    }
  }

  void pause({bool feedback = true}) {
    final wasRunning = clock.running;
    haptics.cancel();
    clock.pause(now);
    ticker.stop();
    if (wasRunning && feedback) cue(BreathCue.pause);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant BreathingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && oldWidget.active) pause(feedback: false);
  }

  void start() {
    clock.start(now);
    if (clock.running) {
      lastPhase =
          clock.elapsed.inMilliseconds ~/ 10000 * 2 +
          (clock.elapsed.inMilliseconds % 10000 >= 4000 ? 1 : 0);
      cue(lastPhase.isEven ? BreathCue.inhale : BreathCue.exhale);
      ticker.start();
    }
    setState(() {});
  }

  @override
  void didPushNext() => pause(feedback: false);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) pause(feedback: false);
  }

  @override
  void deactivate() {
    haptics.cancel();
    clock.pause(now);
    ticker.stop();
    super.deactivate();
  }

  @override
  void dispose() {
    haptics.cancel();
    ticker.dispose();
    auraRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final seconds = clock.elapsed.inMilliseconds / 1000;
    final phase = seconds % 10;
    final inward = phase < 4;
    final progress = inward ? phase / 4 : 1 - (phase - 4) / 6;
    final remaining = (clock.duration - clock.elapsed).inMilliseconds;
    final left = (remaining / 1000).ceil();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaced([
          const Heading('Breathing pause'),
          const Text(
            'Follow along gently, or breathe at your own comfortable pace.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vibration cues'),
            subtitle: const Text(
              'Optional short pulses; device settings and support apply.',
            ),
            value: vibration,
            onChanged: (value) => setState(() {
              vibration = value;
              haptics.cancel();
            }),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final minutes in [1, 3, 5])
                ChoiceChip(
                  label: Text('$minutes min'),
                  selected: clock.duration.inMinutes == minutes,
                  onSelected: clock.running
                      ? null
                      : (_) => setState(() {
                          haptics.cancel();
                          clock.reset();
                          clock.duration = Duration(minutes: minutes);
                        }),
                ),
            ],
          ),
          Text(
            '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
            key: const ValueKey('breathing-remaining'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: Center(
                child: Transform.scale(
                  scale: MediaQuery.disableAnimationsOf(context)
                      ? 1
                      : .65 + .35 * progress,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.lavender,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              clock.complete
                  ? 'Your pause is complete. Take your time.'
                  : inward
                  ? 'Breathe in'
                  : 'Breathe out',
              key: const ValueKey('breathing-guidance'),
              textAlign: TextAlign.center,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: clock.complete
                    ? null
                    : clock.running
                    ? pause
                    : start,
                child: Text(
                  clock.running
                      ? 'Pause breathing'
                      : clock.elapsed == Duration.zero
                      ? 'Start'
                      : 'Resume breathing',
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  haptics.cancel();
                  ticker.stop();
                  setState(clock.reset);
                },
                child: const Text('Reset'),
              ),
              TextButton(
                onPressed: () {
                  pause(feedback: false);
                  setState(clock.reset);
                  cue(BreathCue.finish);
                },
                child: const Text('Stop session'),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}
