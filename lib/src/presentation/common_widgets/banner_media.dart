import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../branding/app_colors.dart';
import 'smart_image.dart';

/// An admin banner: image/GIF through [SmartImage], or a muted looping video
/// when the URL is MP4/WebM (the backend stores videos as-is, so the stored
/// URL keeps the video extension).
class BannerMedia extends StatelessWidget {
  const BannerMedia({super.key, required this.url});

  final String url;

  static bool isVideo(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return path.endsWith('.mp4') || path.endsWith('.webm') || path.endsWith('.mov');
  }

  @override
  Widget build(BuildContext context) => isVideo(url)
      ? _BannerVideo(key: ValueKey(url), url: url)
      : SmartImage(
          url: url,
          category: ImageCategory.food,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
}

class _BannerVideo extends StatefulWidget {
  const _BannerVideo({super.key, required this.url});

  final String url;

  @override
  State<_BannerVideo> createState() => _BannerVideoState();
}

class _BannerVideoState extends State<_BannerVideo> {
  late final VideoPlayerController _video =
      VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _video.initialize().then((_) async {
      await _video.setVolume(0);
      await _video.setLooping(true);
      await _video.play();
      if (mounted) setState(() => _ready = true);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return ColoredBox(color: AppColors.primaryTintStrong);
    final size = _video.value.size;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(_video),
      ),
    );
  }
}
