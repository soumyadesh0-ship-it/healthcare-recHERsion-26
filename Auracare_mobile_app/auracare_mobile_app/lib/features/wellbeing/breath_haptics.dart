import 'package:flutter/services.dart';

enum BreathCue { inhale, exhale, pause, finish }

typedef HapticPulse = Future<void> Function(BreathCue cue);

/// SDK haptics follow platform settings; no custom waveform or new dependency.
class BreathHaptics {
  BreathHaptics({HapticPulse? pulse}) : pulse = pulse ?? platformPulse;
  final HapticPulse pulse;
  Future<void>? active;
  int generation = 0;
  bool supported = true;
  static Future<void> platformPulse(BreathCue cue) => switch (cue) {
    BreathCue.inhale || BreathCue.exhale => HapticFeedback.lightImpact(),
    BreathCue.pause => HapticFeedback.selectionClick(),
    BreathCue.finish => HapticFeedback.mediumImpact(),
  };
  void cancel() {
    generation++;
  }

  Future<void> cue(BreathCue cue) async {
    cancel();
    if (!supported) return;
    final token = generation;
    // Keep at most one platform request in flight. Only the newest waiting
    // transition may send, and pause/exit invalidates it through generation.
    final previous = active;
    if (previous != null) await previous;
    if (token != generation || !supported) return;
    Future<void> send() async {
      if (token != generation || !supported) return;
      try {
        await pulse(cue);
      } on MissingPluginException {
        supported = false;
      } on PlatformException {
        // A temporary platform failure must not disable the whole next session.
      }
    }

    final request = send();
    active = request;
    try {
      await request;
    } finally {
      if (identical(active, request)) active = null;
    }
  }
}
