import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/characters.dart';
import '../../core/widgets.dart';
import 'merge_game.dart';

class MoodFeedback extends StatefulWidget {
  const MoodFeedback({
    super.key,
    required this.mood,
    required this.kind,
    required this.heading,
    required this.message,
    required this.onBreathing,
  });
  final AuraMood mood;
  final AuraCharacter kind;
  final String heading, message;
  final VoidCallback onBreathing;
  @override
  State<MoodFeedback> createState() => _MoodFeedbackState();
}

class _MoodFeedbackState extends State<MoodFeedback>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      animation.value = 1;
    } else {
      animation.forward();
    }
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = animation.value;
      final reduced = MediaQuery.disableAnimationsOf(context);
      return Semantics(
        key: const ValueKey('mood-feedback'),
        liveRegion: true,
        child: Opacity(
          opacity: reduced ? 1 : (t * 6).clamp(0, 1),
          child: Transform.scale(
            scale: reduced ? 1 : 0.96 + 0.04 * (t * 6).clamp(0, 1),
            child: Panel(
              color: Palette.lavender,
              child: Stack(
                children: [
                  if (!reduced && t < 1)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _MoodEffects(widget.mood, t),
                        ),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            reduced
                                ? 0
                                : -7 * math.sin(t * math.pi * 4) * (1 - t),
                          ),
                          child: Character(
                            kind: widget.kind,
                            mood: widget.mood,
                            size: 108,
                          ),
                        ),
                      ),
                      Text(
                        widget.heading,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(widget.message, textAlign: TextAlign.center),
                      if (widget.mood == AuraMood.anxious)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: widget.onBreathing,
                              child: const Text('Try breathing'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  pushPage(context, const MergeGamePage()),
                              child: const Text('Merge & Unwind'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _MoodEffects extends CustomPainter {
  _MoodEffects(this.mood, this.t);
  final AuraMood mood;
  final double t;
  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()
      ..color = Palette.action.withValues(alpha: (1 - t) * 0.35);
    if (mood == AuraMood.anxious) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      c.drawCircle(Offset(s.width / 2, 60), 20 + t * 70, paint);
      return;
    }
    for (var i = 0; i < 12; i++) {
      final x = (i * 43.0 + math.sin(t * math.pi + i) * 16) % s.width;
      final y = (i * 23.0 + t * 80) % s.height;
      if (mood == AuraMood.calm) {
        c.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 12, height: 5),
          paint,
        );
      } else if (mood == AuraMood.happy || mood == AuraMood.energetic) {
        if (mood == AuraMood.happy && i.isEven) {
          c.drawRect(
            Rect.fromCenter(center: Offset(x, y), width: 4, height: 7),
            paint,
          );
        }
        c.drawLine(Offset(x - 4, y), Offset(x + 4, y), paint..strokeWidth = 2);
        c.drawLine(Offset(x, y - 4), Offset(x, y + 4), paint);
      } else {
        c.drawCircle(Offset(x, y), 3 + i % 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MoodEffects old) =>
      old.t != t || old.mood != mood;
}
