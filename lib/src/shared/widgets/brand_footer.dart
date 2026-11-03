import 'package:flutter/material.dart';

/// The sign-off at the end of a long home feed: a large, faded wordmark with a
/// one-line tagline under it.
///
/// Shared so Food and Mart cannot drift into two different sign-offs — only the
/// wordmark and tagline differ, which is exactly what the parameters are for.
///
/// Deliberately quiet: it marks the end of the scroll rather than competing
/// with the content above it, so the wordmark is drawn in the same grey as
/// disabled text rather than in the brand colour.
class BrandFooter extends StatelessWidget {
  const BrandFooter({
    super.key,
    required this.wordmark,
    required this.tagline,
  });

  /// Shown large and faded. Lower-cased on purpose — this is a wordmark, not a
  /// sentence.
  final String wordmark;

  /// One line, under the wordmark.
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scales down rather than wrapping or clipping: a longer wordmark on
          // a narrow phone should shrink, not break in half.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              wordmark.toLowerCase(),
              maxLines: 1,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: onSurface.withValues(alpha: .12),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tagline,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: onSurface.withValues(alpha: .55),
            ),
          ),
        ],
      ),
    );
  }
}
