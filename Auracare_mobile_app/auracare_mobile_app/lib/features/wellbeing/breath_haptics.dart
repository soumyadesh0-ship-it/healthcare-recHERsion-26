import 'dart:async';

import 'package:flutter/services.dart';

enum BreathCue { inhale, exhale, pause, finish }

typedef HapticPulse = Future<void> Function(BreathCue cue);

/// SDK haptics follow platform settings; no custom waveform or new dependency.
class BreathHaptics {
  BreathHaptics({HapticPulse? pulse}) : pulse = pulse ?? platformPulse;
  final HapticPulse pulse;
  Timer? pending;
  int generation = 0;
  bool supported = true;
  static Future<void> platformPulse(BreathCue cue) => switch (cue) {
    BreathCue.inhale || BreathCue.exhale => HapticFeedback.lightImpact(),
    BreathCue.pause => HapticFeedback.selectionClick(),
    BreathCue.finish => HapticFeedback.mediumImpact(),
  };
  void cancel() {
    generation++;
    pending?.cancel();
    pending = null;
  }

  Future<void> cue(BreathCue cue) async {
    cancel();
    if (!supported) return;
    final token = generation;
    Future<void> send() async {
      if (token != generation || !supported) return;
      try {
        await pulse(cue);
      } on MissingPluginException {
        supported = false;
      } on PlatformException {
        supported = false;
      }
    }

    await send();
    if (cue == BreathCue.exhale && supported && token == generation) {
      pending = Timer(const Duration(milliseconds: 120), send);
    }
  }
}
