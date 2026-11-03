import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps the status bar legible against whatever is painted behind it.
///
/// The status bar is transparent throughout Mart, so the colour under it is the
/// screen's own top edge — a category's header gradient on home, the plain
/// surface on a listing. Screens that set no style at all simply inherit the
/// last one pushed, which is how a white listing opened from a dark header
/// ended up with white icons on white.
///
/// Give it the colour actually behind the bar and it picks the icon brightness
/// from that colour's luminance. One rule, so two screens can never disagree.
class StatusBarStyle extends StatelessWidget {
  const StatusBarStyle({
    super.key,
    required this.background,
    required this.child,
  });

  /// The colour painted behind the status bar on this screen.
  final Color background;

  final Widget child;

  /// Slightly below the midpoint: a mid-tone plate carries white better than
  /// dark ink, and Mart's category themes cluster around that midpoint.
  static const _threshold = 0.45;

  static Brightness iconBrightnessOn(Color background) =>
      background.computeLuminance() > _threshold
          ? Brightness.dark
          : Brightness.light;

  @override
  Widget build(BuildContext context) {
    final icons = iconBrightnessOn(background);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        // `statusBarIconBrightness` is Android's knob and `statusBarBrightness`
        // is iOS's, and iOS reads it inverted: there it describes the
        // BACKGROUND, not the icons. Setting both to the same value — which
        // this screen used to do — gets one of the two platforms backwards.
        statusBarIconBrightness: icons,
        statusBarBrightness:
            icons == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: child,
    );
  }
}
