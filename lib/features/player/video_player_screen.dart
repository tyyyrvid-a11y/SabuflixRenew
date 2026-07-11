import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../core/glass/glass_button.dart';
import '../../core/haptics.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/media_item.dart';
import '../../data/services/stream_resolver.dart';
import '../../data/services/watch_history_store.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, this.item, this.localFile, this.localTitle, this.resolvedStream});

  final MediaItem? item;
  final File? localFile;
  final String? localTitle;
  final ResolvedStream? resolvedStream;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  String? _error;
  Timer? _hideTimer;
  int _lastSavedSeconds = -1;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      VideoPlayerController controller;

      if (widget.localFile != null) {
        controller = VideoPlayerController.file(widget.localFile!);
      } else if (widget.resolvedStream != null) {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.resolvedStream!.url),
          httpHeaders: widget.resolvedStream!.headers ?? const {},
        );
      } else if (widget.item != null) {
        final streams = await StreamResolver.resolve(widget.item!);
        final stream = streams.first;
        controller = VideoPlayerController.networkUrl(
          Uri.parse(stream.url),
          httpHeaders: stream.headers ?? const {},
        );
      } else {
        throw Exception('Nenhuma mídia fornecida.');
      }

      await controller.initialize();
      
      if (widget.item != null) {
        final savedPos = WatchHistoryStore.instance.getSavedPosition(widget.item!);
        if (savedPos != null && savedPos > 0) {
          await controller.seekTo(Duration(seconds: savedPos));
        }
      }
      
      controller.addListener(_onTick);
      await controller.play();

      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      _scheduleHide();
    } catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível carregar o vídeo.\n$e');
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
    _saveProgress();
  }

  void _saveProgress({bool force = false}) {
    final controller = _controller;
    if (controller == null || widget.item == null || !controller.value.isInitialized) return;
    
    final pos = controller.value.position.inSeconds;
    final dur = controller.value.duration.inSeconds;
    
    if (force || (pos != _lastSavedSeconds && pos % 5 == 0)) {
      _lastSavedSeconds = pos;
      WatchHistoryStore.instance.markWatched(
        widget.item!, 
        positionInSeconds: pos, 
        durationInSeconds: dur
      );
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    Haptics.light();
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
      _scheduleHide();
    }
    setState(() {});
  }
  
  void _skip(int seconds) {
    final controller = _controller;
    if (controller == null) return;
    Haptics.light();
    final newPosition = controller.value.position + Duration(seconds: seconds);
    controller.seekTo(newPosition);
    _scheduleHide();
  }

  void _toggleFullscreen() {
    Haptics.light();
    setState(() => _fullscreen = !_fullscreen);
    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  @override
  void dispose() {
    _saveProgress(force: true);
    _hideTimer?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isLoaded = controller != null && controller.value.isInitialized;
    final isBuffering = controller != null && controller.value.isBuffering;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isLoaded)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                ),
              ),

            // Apple Style Loading Screen (Blurred Backdrop + Spinner)
            AnimatedOpacity(
              opacity: (isLoaded && !isBuffering && controller.value.isPlaying) ? 0 : 1,
              duration: const Duration(milliseconds: 500),
              child: IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!isLoaded && widget.item != null && widget.item!.backdropUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: widget.item!.backdropUrl,
                        fit: BoxFit.cover,
                      ),
                    if (!isLoaded)
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(color: Colors.black.withOpacity(0.5)),
                      ),
                    if (_error == null)
                      const Center(
                        child: CupertinoActivityIndicator(radius: 18, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),

            // Apple Style Controls
            AnimatedOpacity(
              opacity: _controlsVisible && isLoaded ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_controlsVisible || !isLoaded,
                child: _Controls(
                  title: widget.localTitle ?? widget.item?.title ?? 'Vídeo Local',
                  controller: controller,
                  fullscreen: _fullscreen,
                  onBack: () => Navigator.of(context).pop(),
                  onPlayPause: _togglePlay,
                  onSkipBack: () => _skip(-15),
                  onSkipForward: () => _skip(15),
                  onFullscreen: _toggleFullscreen,
                  formatDuration: _format,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.title,
    required this.controller,
    required this.fullscreen,
    required this.onBack,
    required this.onPlayPause,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.onFullscreen,
    required this.formatDuration,
  });

  final String title;
  final VideoPlayerController? controller;
  final bool fullscreen;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final VoidCallback onFullscreen;
  final String Function(Duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.8),
          ],
          stops: const [0.0, 0.2, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.chevron_back, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.w600, 
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Center Controls (Skip / Play)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: onSkipBack,
                  child: const Icon(CupertinoIcons.gobackward_15, color: Colors.white, size: 40),
                ),
                const SizedBox(width: 48),
                GestureDetector(
                  onTap: onPlayPause,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                    child: Icon(
                      controller != null && controller!.value.isPlaying
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
                GestureDetector(
                  onTap: onSkipForward,
                  child: const Icon(CupertinoIcons.goforward_15, color: Colors.white, size: 40),
                ),
              ],
            ),

            // Bottom Bar (Timeline)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        controller != null ? formatDuration(controller!.value.position) : '--:--',
                        style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        controller != null ? '-${formatDuration(controller!.value.duration - controller!.value.position)}' : '--:--',
                        style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (controller != null && controller!.value.isInitialized)
                    SizedBox(
                      height: 24,
                      child: VideoProgressIndicator(
                        controller!,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        colors: VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white.withOpacity(0.3),
                          backgroundColor: Colors.white.withOpacity(0.15),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: onFullscreen,
                      child: Icon(
                        fullscreen ? CupertinoIcons.arrow_down_right_arrow_up_left : CupertinoIcons.arrow_up_left_arrow_down_right,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
