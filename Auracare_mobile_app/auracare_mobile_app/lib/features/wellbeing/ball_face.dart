import 'package:flutter/material.dart';

import '../../app/theme.dart';

const ballColors = [
  Color(0xFF89BDA3),
  Palette.turquoise,
  Palette.yellow,
  Palette.pink,
  Palette.blue,
  Palette.coral,
  Color(0xFFB9AACF),
  Palette.purple,
  Color(0xFFC7AE85),
  Color(0xFFB67EA0),
];
const ballNames = [
  'Green',
  'Turquoise',
  'Gold',
  'Pink',
  'Blue',
  'Coral',
  'Lavender',
  'Purple',
  'Sand',
  'Rose',
];
Color ballColor(int value) => ballColors[value - 1];
String ballName(int value) => ballNames[value - 1];

/// A drawn face for each internal value. Coordinates are
/// relative to the existing physics radius; rendering never changes collisions.
void paintBallFace(
  Canvas c,
  int value,
  double radius, {
  double expression = 1,
}) {
  final happy = ((value - 1) / 9 * expression).clamp(0.0, 1.0);
  c.drawCircle(Offset.zero, radius, Paint()..color = ballColor(value));
  final ink = Paint()
    ..color = Palette.flowInk
    ..strokeWidth = radius * .075
    ..strokeCap = StrokeCap.round;
  for (final side in [-1, 1]) {
    final x = side * radius * .32;
    c.drawCircle(Offset(x, -radius * .23), radius * .065, ink);
    if (value < 5) {
      c.drawLine(
        Offset(x - side * radius * .13, -radius * .50),
        Offset(x + side * radius * .13, -radius * (.30 + .18 * happy)),
        ink,
      );
    }
  }
  final mouth = Path()
    ..moveTo(-radius * .30, radius * .10)
    ..quadraticBezierTo(
      0,
      radius * (.10 + (happy - .45) * .65),
      radius * .30,
      radius * .10,
    );
  c.drawPath(mouth, ink..style = PaintingStyle.stroke);
}
