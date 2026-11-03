import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// A heading that arrives, performs, and leaves — on a loop.
///
/// Four beats, in order, repeating forever:
///  1. **In** — scales up from nothing to full size, overshooting slightly
///     before it settles, so it lands rather than merely stops growing.
///  2. **Bounce** — at full size, the characters hop upward one after another,
///     left to right, in a wave that crosses the whole heading once.
///  3. **Out** — scales back down to nothing, winding up a touch first.
///  4. **Gap** — nothing on screen, then it all begins again.
///
/// The wave's stagger is per character rather than per heading, so a long
/// backend heading sweeps at the same pace as a short one; only the cycle gets
/// longer. [cycleFor] is the whole loop's length for a given heading.
///
/// This is the only place the motion is defined, so every sale banner and
/// section title animates identically. Give it whatever heading the backend
/// sends; the text needs to know nothing about the animation.
///
/// It takes [text] and [style] rather than a child widget because it has to
/// split the string itself. That split is a PAINTING detail, not a semantic
/// one: the characters are wrapped in [Semantics] carrying the whole string, so
/// a screen reader announces "Grocery Sale" once, steadily, however the visual
/// is scaling at the time.
///
/// Every beat is a paint-time transform, so the heading holds its final
/// footprint from the first frame to the last — including while it is scaled
/// away to nothing. Nothing around it reflows as it comes and goes.
class BouncingHeading extends StatefulWidget {
  const BouncingHeading({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  /// Beat 1: nothing → full size.
  static const enterDuration = Duration(milliseconds: 420);

  /// Beat 3: full size → nothing.
  static const exitDuration = Duration(milliseconds: 340);

  /// Beat 4: the empty pause before it returns.
  static const gapDuration = Duration(milliseconds: 260);

  /// One character's rise-and-settle within beat 2.
  static const hopDuration = Duration(milliseconds: 420);

  /// Delay between neighbours — this is what makes the wave travel rightward.
  static const staggerDuration = Duration(milliseconds: 55);

  /// Beat after the last character lands, before the heading scales away.
  static const restDuration = Duration(milliseconds: 400);

  /// How high a character rises. Small on purpose: the heading has to stay
  /// comfortably readable while it moves.
  static const double amplitude = 6;

  /// Length of beat 2 for a heading of [glyphCount] characters.
  static Duration bounceFor(int glyphCount) =>
      staggerDuration * math.max(0, glyphCount - 1) +
      hopDuration +
      restDuration;

  /// Length of the whole in-bounce-out-gap loop.
  static Duration cycleFor(int glyphCount) =>
      enterDuration + bounceFor(glyphCount) + exitDuration + gapDuration;

  @override
  State<BouncingHeading> createState() => _BouncingHeadingState();
}

class _BouncingHeadingState extends State<BouncingHeading>
    with SingleTickerProviderStateMixin {
  /// One controller for the whole loop rather than one per beat: the beats are
  /// strictly sequential, so a single timeline keeps them in step by
  /// construction — no listener has to hand off to the next stage, and the
  /// wave cannot start while the heading is still arriving.
  late final AnimationController _controller;

  /// Grapheme clusters, not code units: splitting on `''` would tear an emoji
  /// or an accented character into halves that render as tofu.
  late List<String> _glyphs;

  @override
  void initState() {
    super.initState();
    _glyphs = widget.text.characters.toList();
    _controller = AnimationController(vsync: this, duration: _cycle)..repeat();
  }

  @override
  void didUpdateWidget(BouncingHeading old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    // A new heading gets a fresh arrival. Switching category mid-loop would
    // otherwise drop the new text in halfway through someone else's exit.
    _glyphs = widget.text.characters.toList();
    _controller
      ..stop()
      ..duration = _cycle
      ..forward(from: 0)
      ..repeat();
  }

  Duration get _cycle => BouncingHeading.cycleFor(_glyphs.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Where character [index] sits, in logical pixels above its baseline, given
  /// how far into beat 2 the loop is. Null elapsed means the beat is not
  /// running, so every character rests.
  double _lift(int index, Duration? bounceElapsed) {
    if (bounceElapsed == null) return 0;
    final local = bounceElapsed - BouncingHeading.staggerDuration * index;
    if (local.isNegative || local > BouncingHeading.hopDuration) return 0;
    final progress =
        local.inMicroseconds / BouncingHeading.hopDuration.inMicroseconds;
    // A half sine: up and back down in one smooth arc, ending exactly where it
    // started so nothing drifts over repeated cycles.
    return -BouncingHeading.amplitude * math.sin(progress * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final beat = _Beat.at(
              _controller.duration! * _controller.value,
              _glyphs.length,
            );

            return Opacity(
              opacity: beat.opacity,
              child: Transform.scale(
                scale: beat.scale,
                // Scaled down to fit rather than overflowing. The glyph row is
                // as wide as the font that actually loads and the system text
                // size make it, so a heading that fits at the defaults can
                // still run past its space — and a clipped, striped heading is
                // worse than a slightly smaller one.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < _glyphs.length; i++)
                        Transform.translate(
                          offset: Offset(0, _lift(i, beat.bounceElapsed)),
                          child: Text(
                            _glyphs[i],
                            style: widget.style,
                            // Each glyph is its own box, so a soft-wrap decision
                            // here would be meaningless — and a space must keep
                            // its width rather than being collapsed away.
                            softWrap: false,
                            maxLines: 1,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The heading's state at one instant of the loop.
@immutable
class _Beat {
  const _Beat({
    required this.scale,
    required this.opacity,
    required this.bounceElapsed,
  });

  final double scale;
  final double opacity;

  /// How far into the bounce beat, or null outside it.
  final Duration? bounceElapsed;

  factory _Beat.at(Duration elapsed, int glyphCount) {
    const enter = BouncingHeading.enterDuration;
    final bounce = BouncingHeading.bounceFor(glyphCount);
    const exit = BouncingHeading.exitDuration;

    if (elapsed < enter) {
      final t = elapsed.inMicroseconds / enter.inMicroseconds;
      return _Beat(
        // easeOutBack deliberately overshoots past 1: the heading grows a touch
        // beyond full size and settles back, which is what makes it land.
        scale: lerpDouble(0, 1, Curves.easeOutBack.transform(t))!,
        // Ahead of the scale, so the heading is legible for most of its
        // arrival instead of fading in at the very end.
        opacity: Curves.easeOutCubic.transform(t).clamp(0.0, 1.0),
        bounceElapsed: null,
      );
    }

    if (elapsed < enter + bounce) {
      return _Beat(scale: 1, opacity: 1, bounceElapsed: elapsed - enter);
    }

    if (elapsed < enter + bounce + exit) {
      final t = (elapsed - enter - bounce).inMicroseconds / exit.inMicroseconds;
      return _Beat(
        // easeInBack winds up the other way — a slight swell before it
        // collapses, mirroring the overshoot on the way in.
        scale: lerpDouble(1, 0, Curves.easeInBack.transform(t))!,
        opacity: (1 - Curves.easeInCubic.transform(t)).clamp(0.0, 1.0),
        bounceElapsed: null,
      );
    }

    // The empty gap before the next arrival.
    return const _Beat(scale: 0, opacity: 0, bounceElapsed: null);
  }
}
