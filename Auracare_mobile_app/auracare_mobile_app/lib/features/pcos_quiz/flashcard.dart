import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Presentation only: field keys and nullable answers stay in the quiz state.
class QuizFlashcard extends StatelessWidget {
  const QuizFlashcard({
    super.key,
    required this.field,
    required this.question,
    required this.index,
    required this.selected,
    required this.answered,
    required this.onAnswer,
  });

  final String field, question;
  final int index;
  final int? selected;
  final bool answered;
  final ValueChanged<int?> onAnswer;

  static const colors = [
    Palette.lavender,
    Palette.blush,
    Palette.yellow,
    Palette.periwinkle,
    Palette.turquoise,
    Palette.blush,
  ];

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('flashcard-$field'),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: colors[index % colors.length],
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ExcludeSemantics(
            child: CustomPaint(
              size: const Size(112, 104),
              painter: _QuestionArtwork(field),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          question,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'Choose what fits. It is okay to be unsure.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        for (final option in <(int?, String)>[
          (1, 'Yes'),
          (0, 'No'),
          (null, 'Not sure'),
        ]) ...[
          Semantics(
            selected: answered && selected == option.$1,
            child: OutlinedButton(
              key: ValueKey('answer-${option.$2}'),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                backgroundColor: answered && selected == option.$1
                    ? Palette.ink
                    : Palette.white,
                foregroundColor: answered && selected == option.$1
                    ? Palette.white
                    : Palette.ink,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onPressed: () => onAnswer(option.$1),
              child: Row(
                children: [
                  Expanded(child: Text(option.$2)),
                  if (answered && selected == option.$1)
                    const Icon(Icons.check_rounded, size: 22),
                ],
              ),
            ),
          ),
          if (option.$2 != 'Not sure') const SizedBox(height: 10),
        ],
      ],
    ),
  );
}

class QuizCardTransition extends StatelessWidget {
  const QuizCardTransition({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250),
    switchInCurve: Curves.easeOut,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(.05, .02),
          end: Offset.zero,
        ).animate(animation),
        child: ScaleTransition(
          scale: Tween<double>(begin: .98, end: 1).animate(animation),
          child: child,
        ),
      ),
    ),
    child: child,
  );
}

/// Original flat line drawings; decorative rather than anatomical diagrams.
class _QuestionArtwork extends CustomPainter {
  const _QuestionArtwork(this.field);
  final String field;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = Palette.white;
    final box = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 16, 80, 76),
      const Radius.circular(16),
    );
    if (field == 'regular_periods') {
      canvas.drawRRect(box, fill);
      canvas.drawRRect(box, line);
      canvas.drawLine(const Offset(16, 37), const Offset(96, 37), line);
      for (final x in [35.0, 77.0]) {
        canvas.drawLine(Offset(x, 9), Offset(x, 24), line);
      }
      final dot = Paint()..color = Palette.pink;
      for (final x in [35.0, 56.0, 77.0]) {
        for (final y in [53.0, 74.0]) {
          canvas.drawCircle(Offset(x, y), 5, dot);
        }
      }
    } else if (field == 'weight_gain') {
      canvas.drawRRect(box, fill);
      canvas.drawRRect(box, line);
      canvas.drawArc(
        const Rect.fromLTWH(32, 28, 48, 40),
        3.14,
        3.14,
        false,
        line,
      );
      canvas.drawLine(const Offset(56, 48), const Offset(67, 34), line);
      canvas.drawLine(const Offset(37, 76), const Offset(75, 76), line);
    } else if (field == 'skin_darkening') {
      canvas.drawCircle(const Offset(44, 45), 28, fill);
      canvas.drawCircle(
        const Offset(69, 64),
        28,
        Paint()..color = Palette.pink,
      );
      canvas.drawCircle(const Offset(44, 45), 28, line);
      canvas.drawCircle(const Offset(69, 64), 28, line);
    } else if (field == 'acne') {
      canvas.drawOval(const Rect.fromLTWH(23, 9, 66, 86), fill);
      canvas.drawOval(const Rect.fromLTWH(23, 9, 66, 86), line);
      canvas.drawLine(const Offset(38, 43), const Offset(43, 43), line);
      canvas.drawLine(const Offset(69, 43), const Offset(74, 43), line);
      canvas.drawArc(const Rect.fromLTWH(45, 59, 22, 15), 0, 3.14, false, line);
      for (final point in [
        const Offset(34, 56),
        const Offset(78, 60),
        const Offset(71, 76),
      ]) {
        canvas.drawCircle(point, 3, Paint()..color = Palette.coral);
      }
    } else {
      canvas.drawRRect(box, fill);
      canvas.drawLine(const Offset(23, 78), const Offset(89, 78), line);
      for (final x
          in field == 'hair_thinning' ? [44.0, 70.0] : [32.0, 56.0, 80.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(x, 84)
            ..cubicTo(x - 20, 60, x + 19, 40, x - 3, 22),
          line,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QuestionArtwork oldDelegate) =>
      field != oldDelegate.field;
}
