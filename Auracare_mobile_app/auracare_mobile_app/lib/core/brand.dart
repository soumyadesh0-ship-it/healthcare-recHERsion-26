import 'package:flutter/material.dart';

import '../app/theme.dart';

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

class AuraCareBrandHeader extends StatelessWidget {
  const AuraCareBrandHeader({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'AuraCare',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/brand/auracare-icon.png',
            width: 36,
            height: 36,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              'auracare',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  Theme.of(context).appBarTheme.titleTextStyle ??
                  const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Palette.ink,
                  ),
            ),
          ),
        ],
      ),
    ),
  );
}

class AuraLogoIcon extends StatelessWidget {
  const AuraLogoIcon({super.key});
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/auracare-icon.png',
    width: 40,
    height: 40,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}
