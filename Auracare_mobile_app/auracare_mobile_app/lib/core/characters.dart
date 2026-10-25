import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

enum AuraCharacter { flower, diamond, circle, cloud, square, blob }

enum AuraMood { happy, calm, sad, anxious, tired, energetic }

class Character extends StatelessWidget {
  const Character({
    super.key,
    this.kind = AuraCharacter.flower,
    this.mood = AuraMood.happy,
    this.size = 120,
  });
  final AuraCharacter kind;
  final AuraMood mood;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _CharacterPainter(kind, mood)),
    ),
  );
}

class _CharacterPainter extends CustomPainter {
  const _CharacterPainter(this.kind, this.mood);
  final AuraCharacter kind;
  final AuraMood mood;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final fill = Paint()
      ..color = switch (kind) {
        AuraCharacter.flower => Palette.pink,
        AuraCharacter.diamond => Palette.turquoise,
        AuraCharacter.circle => Palette.coral,
        AuraCharacter.cloud => Palette.blue,
        AuraCharacter.square => Palette.yellow,
        AuraCharacter.blob => Palette.lavender,
      };
    switch (kind) {
      case AuraCharacter.flower:
        for (var i = 0; i < 7; i++) {
          final a = i * math.pi * 2 / 7;
          canvas.drawCircle(
            Offset(50 + math.cos(a) * 25, 50 + math.sin(a) * 25),
            19,
            fill,
          );
        }
        canvas.drawCircle(const Offset(50, 50), 27, fill);
      case AuraCharacter.diamond:
        canvas.save();
        canvas.translate(50, 50);
        canvas.rotate(math.pi / 4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-31, -31, 62, 62),
            const Radius.circular(18),
          ),
          fill,
        );
        canvas.restore();
      case AuraCharacter.circle:
        canvas.drawCircle(const Offset(50, 50), 41, fill);
      case AuraCharacter.cloud:
        canvas.drawCircle(const Offset(29, 55), 22, fill);
        canvas.drawCircle(const Offset(48, 35), 25, fill);
        canvas.drawCircle(const Offset(71, 48), 22, fill);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(15, 48, 74, 34),
            const Radius.circular(17),
          ),
          fill,
        );
      case AuraCharacter.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(10, 10, 80, 80),
            const Radius.circular(24),
          ),
          fill,
        );
      case AuraCharacter.blob:
        final path = Path()
          ..moveTo(18, 30)
          ..cubicTo(28, 0, 60, 9, 72, 20)
          ..cubicTo(100, 28, 94, 54, 84, 66)
          ..cubicTo(77, 95, 51, 98, 39, 83)
          ..cubicTo(5, 87, 1, 54, 18, 30)
          ..close();
        canvas.drawPath(path, fill);
    }
    final ink = Paint()..color = Palette.ink;
    final stroke = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (final x in [40.0, 60.0]) {
      if (mood == AuraMood.calm || mood == AuraMood.tired) {
        canvas.drawLine(
          Offset(x - 3, 47),
          Offset(x + 3, mood == AuraMood.tired ? 46 : 47),
          stroke,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, 46), width: 3.8, height: 6.5),
          ink,
        );
      }
    }
    if (mood == AuraMood.anxious) {
      canvas.drawLine(const Offset(36, 37), const Offset(43, 39), stroke);
      canvas.drawLine(const Offset(57, 39), const Offset(64, 37), stroke);
      canvas.drawOval(const Rect.fromLTWH(47, 57, 6, 8), stroke);
    } else if (mood == AuraMood.sad) {
      canvas.drawArc(
        const Rect.fromLTWH(43, 58, 14, 10),
        math.pi,
        math.pi,
        false,
        stroke,
      );
    } else {
      canvas.drawArc(
        Rect.fromLTWH(43, 51, 14, mood == AuraMood.energetic ? 18 : 12),
        0,
        math.pi,
        false,
        stroke,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CharacterPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.mood != mood;
}

class CharacterCluster extends StatelessWidget {
  const CharacterCluster({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(constraints.maxWidth, 420.0);
      return SizedBox(
        width: width,
        height: width * .65,
        child: Stack(
          children: [
            for (var i = 0; i < AuraCharacter.values.length; i++)
              Positioned(
                left: width * [0.0, .31, .63, .03, .35, .65][i],
                top: width * [0.0, .04, 0.0, .29, .31, .28][i],
                child: Transform.rotate(
                  angle: i.isEven ? -.12 : .12,
                  child: Character(
                    kind: AuraCharacter.values[i],
                    size: width * .34,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
