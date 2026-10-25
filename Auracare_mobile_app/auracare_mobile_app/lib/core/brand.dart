import 'package:flutter/material.dart';

/// Cleaned lockup from the supplied logo reference, never stretched or clipped.
class AuraLogo extends StatelessWidget {
  const AuraLogo({super.key, this.width = 260, this.wordmarkOnly = false});
  final double width;
  final bool wordmarkOnly;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'AuraCare. Your Body. Your Space.',
    image: true,
    child: ExcludeSemantics(
      child: Image.asset(
        wordmarkOnly
            ? 'assets/brand/auracare-wordmark.png'
            : 'assets/brand/auracare-lockup.png',
        width: width,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    ),
  );
}
