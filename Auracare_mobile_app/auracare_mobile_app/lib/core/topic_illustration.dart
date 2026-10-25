import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

enum TopicMotif {
  flower,
  droplet,
  circles,
  sprout,
  mother,
  embrace,
  moon,
  sun,
  leaf,
  dots,
  face,
  checklist,
}

class TopicIllustration extends StatelessWidget {
  const TopicIllustration({super.key, required this.topic});
  final String topic;
  TopicMotif get motif => switch (topic) {
    'Puberty & adolescence' => TopicMotif.flower,
    'First periods & menstrual health' => TopicMotif.droplet,
    'Hormonal & reproductive health' => TopicMotif.circles,
    'Fertility & preconception' => TopicMotif.sprout,
    'Pregnancy' => TopicMotif.mother,
    'Postpartum' => TopicMotif.embrace,
    'Perimenopause' => TopicMotif.moon,
    'Menopause' => TopicMotif.sun,
    'Later-life wellbeing' => TopicMotif.leaf,
    'PCOS' => TopicMotif.dots,
    'Symptoms & terminology' => TopicMotif.face,
    'Appointment preparation' => TopicMotif.checklist,
    _ => TopicMotif.flower,
  };
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 46,
      child: CustomPaint(painter: _TopicPainter(motif)),
    ),
  );
}

class _TopicPainter extends CustomPainter {
  const _TopicPainter(this.motif);
  final TopicMotif motif;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    final ink = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    void circle(double x, double y, double r, Color color) =>
        canvas.drawCircle(Offset(x, y), r, Paint()..color = color);
    void leaf(double x, double y, double angle) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.drawOval(
        const Rect.fromLTWH(-3, -9, 14, 10),
        Paint()..color = Palette.turquoise,
      );
      canvas.restore();
    }

    void heart(double x, double y, double scale, Color color) {
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(scale);
      final path = Path()
        ..moveTo(0, 5)
        ..cubicTo(-18, -6, -9, -19, 0, -10)
        ..cubicTo(9, -19, 18, -6, 0, 5)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
      canvas.restore();
    }

    switch (motif) {
      case TopicMotif.flower:
        canvas.drawLine(const Offset(24, 26), const Offset(24, 43), ink);
        leaf(23, 36, -.3);
        for (var i = 0; i < 5; i++) {
          final a = i * math.pi * 2 / 5;
          circle(24 + math.cos(a) * 8, 16 + math.sin(a) * 8, 6, Palette.pink);
        }
        circle(24, 16, 5, Palette.yellow);
      case TopicMotif.droplet:
        final path = Path()
          ..moveTo(24, 4)
          ..cubicTo(20, 13, 9, 22, 9, 30)
          ..cubicTo(9, 48, 39, 48, 39, 30)
          ..cubicTo(39, 22, 28, 13, 24, 4)
          ..close();
        canvas.drawPath(path, Paint()..color = Palette.pink);
        canvas.drawArc(
          const Rect.fromLTWH(15, 23, 16, 15),
          .3,
          1.3,
          false,
          ink,
        );
      case TopicMotif.circles:
        canvas.drawLine(const Offset(12, 16), const Offset(36, 15), ink);
        canvas.drawLine(const Offset(12, 16), const Offset(25, 37), ink);
        canvas.drawLine(const Offset(36, 15), const Offset(25, 37), ink);
        circle(12, 16, 9, Palette.turquoise);
        circle(36, 15, 9, Palette.pink);
        circle(25, 37, 9, Palette.yellow);
      case TopicMotif.sprout:
        canvas.drawLine(const Offset(24, 41), const Offset(24, 18), ink);
        leaf(21, 22, 2.9);
        leaf(26, 16, .1);
        canvas.drawOval(
          const Rect.fromLTWH(10, 38, 28, 7),
          Paint()..color = Palette.purple,
        );
      case TopicMotif.mother:
        circle(20, 11, 8, Palette.purple);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(10, 19, 20, 25),
            const Radius.circular(10),
          ),
          Paint()..color = Palette.purple,
        );
        circle(29, 31, 12, Palette.pink);
        heart(30, 33, .55, Palette.white);
      case TopicMotif.embrace:
        circle(14, 13, 7, Palette.purple);
        circle(32, 18, 6, Palette.pink);
        canvas.drawArc(
          const Rect.fromLTWH(5, 16, 36, 27),
          0,
          math.pi,
          false,
          Paint()
            ..color = Palette.purple
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round,
        );
        heart(25, 32, .55, Palette.pink);
      case TopicMotif.moon:
        final path = Path.combine(
          PathOperation.difference,
          Path()..addOval(const Rect.fromLTWH(6, 5, 35, 37)),
          Path()..addOval(const Rect.fromLTWH(20, 1, 30, 30)),
        );
        canvas.drawPath(path, Paint()..color = Palette.purple);
        circle(36, 11, 3, Palette.yellow);
        circle(32, 21, 2, Palette.yellow);
      case TopicMotif.sun:
        circle(24, 24, 12, Palette.yellow);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            Offset(24 + math.cos(a) * 17, 24 + math.sin(a) * 17),
            Offset(24 + math.cos(a) * 21, 24 + math.sin(a) * 21),
            ink,
          );
        }
      case TopicMotif.leaf:
        canvas.save();
        canvas.translate(24, 24);
        canvas.rotate(-.7);
        canvas.drawOval(
          const Rect.fromLTWH(-13, -20, 26, 40),
          Paint()..color = Palette.turquoise,
        );
        canvas.drawLine(const Offset(0, -12), const Offset(0, 25), ink);
        canvas.drawLine(const Offset(0, 5), const Offset(8, -2), ink);
        canvas.restore();
      case TopicMotif.dots:
        circle(24, 24, 5, Palette.purple);
        for (var i = 0; i < 7; i++) {
          final a = i * math.pi * 2 / 7;
          circle(
            24 + math.cos(a) * 16,
            24 + math.sin(a) * 16,
            5,
            i.isEven ? Palette.pink : Palette.purple,
          );
        }
      case TopicMotif.face:
        circle(24, 24, 20, Palette.yellow);
        circle(18, 21, 1.5, Palette.ink);
        circle(30, 21, 1.5, Palette.ink);
        canvas.drawArc(
          const Rect.fromLTWH(18, 24, 12, 10),
          0,
          math.pi,
          false,
          ink,
        );
      case TopicMotif.checklist:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(9, 7, 30, 37),
            const Radius.circular(5),
          ),
          Paint()..color = Palette.blue,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(17, 3, 14, 9),
            const Radius.circular(3),
          ),
          Paint()..color = Palette.purple,
        );
        for (final y in [20.0, 31.0]) {
          canvas.drawLine(Offset(15, y), Offset(18, y + 3), ink);
          canvas.drawLine(Offset(18, y + 3), Offset(22, y - 3), ink);
          canvas.drawLine(Offset(27, y), Offset(33, y), ink);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TopicPainter oldDelegate) => oldDelegate.motif != motif;
}
