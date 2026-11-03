import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../branding/theme_color_provider.dart';
import '../navigation/route_names.dart';

/// The raised disc in the middle of the food bottom bar that opens the Taxi
/// section. The taxi bottom bar carries the matching "Food" button back.
class ModeSwitchButton extends ConsumerStatefulWidget {
  const ModeSwitchButton({super.key, this.diameter = 56});

  final double diameter;

  @override
  ConsumerState<ModeSwitchButton> createState() => _ModeSwitchButtonState();
}

class _ModeSwitchButtonState extends ConsumerState<ModeSwitchButton>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 320);

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0,
    upperBound: 0.08,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _openTaxi() async {
    // Press-in, then release — the scale settles while the route is already
    // changing, so the gesture reads as one motion rather than two steps.
    await _press.forward();
    if (!mounted) return;
    unawaited(_press.reverse());
    // `go`, not `push`: the taxi section replaces the food stack; its own
    // bottom bar has the way back to Food.
    context.go(RouteNames.taxi);
  }

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(themeColorProvider).color;
    const icon = Icons.local_taxi_rounded;
    const label = 'Taxi';

    return Semantics(
      button: true,
      label: 'Switch to $label',
      child: GestureDetector(
        onTap: _openTaxi,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: widget.diameter + 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lifted so the disc floats proud of the bar. Nothing clips here,
              // which is what lets it overlap the bar's top edge.
              Transform.translate(
                offset: const Offset(0, -14),
                child: AnimatedBuilder(
                  animation: _press,
                  builder: (context, child) => Transform.scale(
                    scale: 1 - _press.value,
                    child: child,
                  ),
                  child: AnimatedContainer(
                    duration: _duration,
                    curve: Curves.easeOutCubic,
                    width: widget.diameter,
                    height: widget.diameter,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: _duration,
                      switchInCurve: Curves.easeOutBack,
                      // Rotate + fade, so the icon turns over into the new one
                      // rather than popping.
                      transitionBuilder: (child, animation) => RotationTransition(
                        turns: Tween<double>(begin: 0.6, end: 1).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: Icon(
                        icon,
                        key: ValueKey(icon.codePoint),
                        color: Colors.white,
                        size: widget.diameter * 0.44,
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -10),
                child: AnimatedDefaultTextStyle(
                  duration: _duration,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  child: Text(label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Local `unawaited` so the reverse animation is explicitly fire-and-forget.
void unawaited(Future<void> _) {}
