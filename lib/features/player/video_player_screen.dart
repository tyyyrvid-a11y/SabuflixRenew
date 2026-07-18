import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/glass/glass_button.dart';
import '../../core/haptics.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/media_item.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import '../../data/services/stream_resolver.dart';
import '../../data/services/watch_history_store.dart';
import '../../data/services/cast_service.dart';
import 'widgets/cast_device_selector.dart';
import 'widgets/track_selector_sheet.dart';

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
  late final Player player;
  late final VideoController videoController;

  bool _isLoaded = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;

  bool _controlsVisible = true;
  bool _fullscreen = false;
  String? _error;
  Timer? _hideTimer;
  int _lastSavedSeconds = -1;

  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _bufferingSub;

  @override
  void initState() {
    super.initState();
    player = Player();
    videoController = VideoController(player);
    SimplePip().setAutoPipMode(aspectRatio: const (16, 9));
    _init();
  }

  Future<void> _init() async {
    try {
      _playingSub = player.stream.playing.listen((v) => setState(() => _isPlaying = v));
      _positionSub = player.stream.position.listen((v) {
        setState(() => _position = v);
        _saveProgress();
      });
      _durationSub = player.stream.duration.listen((v) => setState(() => _duration = v));
      _bufferSub = player.stream.buffer.listen((v) => setState(() => _buffer = v));
      _bufferingSub = player.stream.buffering.listen((v) => setState(() => _isBuffering = v));
      _errorSub = player.stream.error.listen((e) => setState(() => _error = 'Erro no vídeo:\n$e'));

      player.stream.videoParams.listen((v) {
        if (!_isLoaded && v.w != null && v.w! > 0) {
          setState(() => _isLoaded = true);
        }
      });

      Media media;
      if (widget.localFile != null) {
        media = Media(widget.localFile!.path);
      } else if (widget.resolvedStream != null) {
        media = Media(widget.resolvedStream!.url, httpHeaders: widget.resolvedStream!.headers);
      } else if (widget.item != null) {
        final streams = await StreamResolver.resolve(widget.item!);
        final stream = streams.first;
        media = Media(stream.url, httpHeaders: stream.headers);
      } else {
        throw Exception('Nenhuma mídia fornecida.');
      }

      await player.open(media, play: false);

      if (widget.item != null) {
        final savedPos = WatchHistoryStore.instance.getSavedPosition(widget.item!);
        if (savedPos != null && savedPos > 0) {
          await player.seek(Duration(seconds: savedPos));
        }
      }

      await player.play();
      _scheduleHide();
      
      // Fallback para isLoaded se videoParams atrasar
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && !_isLoaded) setState(() => _isLoaded = true);
      });

      CastService.instance.addListener(_onCastStateChanged);
    } catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível carregar o vídeo.\n$e');
    }
  }

  void _onCastStateChanged() {
    if (mounted) {
      setState(() {});
      if (CastService.instance.isCasting && _isPlaying) {
        player.pause(); // Pausa local quando estiver no cast
      }
    }
  }

  void _saveProgress({bool force = false}) {
    if (widget.item == null || !_isLoaded) return;
    
    final pos = _position.inSeconds;
    final dur = _duration.inSeconds;
    
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
      if (mounted && _isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _togglePlay() {
    Haptics.light();
    if (CastService.instance.isCasting) {
      CastService.instance.togglePlay();
      _scheduleHide();
      return;
    }
    if (_isPlaying) {
      player.pause();
    } else {
      player.play();
      _scheduleHide();
    }
  }
  
  void _skip(int seconds) {
    Haptics.light();
    if (CastService.instance.isCasting) {
      final newPosition = CastService.instance.position + Duration(seconds: seconds);
      CastService.instance.seek(newPosition);
    } else {
      final newPosition = _position + Duration(seconds: seconds);
      player.seek(newPosition);
    }
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
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferSub?.cancel();
    _errorSub?.cancel();
    _bufferingSub?.cancel();
    player.dispose();
    CastService.instance.removeListener(_onCastStateChanged);
    if (CastService.instance.isCasting) {
      CastService.instance.stop();
    }
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
    final videoLayer = Video(
      controller: videoController,
      controls: NoVideoControls,
    );

    return PipWidget(
      pipBuilder: (context) => Scaffold(
        backgroundColor: Colors.black,
        body: videoLayer,
      ),
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (CastService.instance.isCasting)
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.tv, color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Transmitindo para\n${CastService.instance.currentDevice?.name ?? 'Smart TV'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: () => CastService.instance.stop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text('Parar Transmissão', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              videoLayer,
            
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                ),
              ),

            // Apple Style Loading Screen (Blurred Backdrop + Spinner)
            AnimatedOpacity(
              opacity: (_isLoaded && !_isBuffering && _isPlaying) ? 0 : 1,
              duration: const Duration(milliseconds: 500),
              child: IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!_isLoaded && widget.item != null && widget.item!.backdropUrl.isNotEmpty)
                      Image.network(
                        widget.item!.backdropUrl,
                        fit: BoxFit.cover,
                      ),
                    if (!_isLoaded)
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(color: Colors.black.withOpacity(0.5)),
                      ),
                    if (_error == null && (!_isLoaded || _isBuffering))
                      const Center(
                        child: CupertinoActivityIndicator(radius: 18, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),

            // Apple Style Controls
            AnimatedOpacity(
              opacity: _controlsVisible && _isLoaded ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_controlsVisible || !_isLoaded,
                child: _Controls(
                  title: widget.localTitle ?? widget.item?.title ?? 'Vídeo Local',
                  isPlaying: CastService.instance.isCasting ? CastService.instance.isPlaying : _isPlaying,
                  position: CastService.instance.isCasting ? CastService.instance.position : _position,
                  duration: CastService.instance.isCasting ? CastService.instance.duration : _duration,
                  buffer: _buffer,
                  fullscreen: _fullscreen,
                  onBack: () => Navigator.of(context).pop(),
                  onPlayPause: _togglePlay,
                  onSkipBack: () => _skip(-15),
                  onSkipForward: () => _skip(15),
                  onFullscreen: _toggleFullscreen,
                  formatDuration: _format,
                  onSeek: (pos) {
                    if (CastService.instance.isCasting) {
                      CastService.instance.seek(pos);
                    } else {
                      player.seek(pos);
                    }
                    _scheduleHide();
                  },
                  onCast: () {
                    CastDeviceSelector.show(context, onDeviceSelected: (device) {
                      String mediaUrl = '';
                      if (widget.resolvedStream != null) {
                        mediaUrl = widget.resolvedStream!.url;
                      } else if (widget.item != null) {
                        // Idealmente deveria resolver novamente se não estiver em cache, mas para simplificar:
                        mediaUrl = player.state.playlist.medias.first.uri;
                      }
                      
                      if (mediaUrl.isNotEmpty) {
                        CastService.instance.connectAndPlay(
                          device,
                          mediaUrl,
                          widget.localTitle ?? widget.item?.title ?? 'Vídeo Local',
                        );
                      }
                    });
                  },
                  onPip: () => SimplePip().enterPipMode(aspectRatio: const (16, 9)),
                  onSettings: () {
                    _hideTimer?.cancel();
                    TrackSelectorSheet.show(context, player);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.title,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.buffer,
    required this.fullscreen,
    required this.onBack,
    required this.onPlayPause,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.onFullscreen,
    required this.formatDuration,
    required this.onSeek,
    required this.onCast,
    required this.onPip,
    required this.onSettings,
  });

  final String title;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final bool fullscreen;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final VoidCallback onFullscreen;
  final String Function(Duration) formatDuration;
  final Function(Duration) onSeek;
  final VoidCallback onCast;
  final VoidCallback onPip;
  final VoidCallback onSettings;

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
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onSettings,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.captions_bubble, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onPip,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.rectangle_on_rectangle_angled, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onCast,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: CastService.instance.isCasting ? AppColors.accent : Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CastService.instance.isCasting ? CupertinoIcons.tv_fill : CupertinoIcons.tv, 
                        color: Colors.white, 
                        size: 20
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
                      isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
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
                        formatDuration(position),
                        style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '-${formatDuration(duration - position)}',
                        style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 24,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withOpacity(0.2),
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                        max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1,
                        onChanged: (val) {
                          onSeek(Duration(milliseconds: val.toInt()));
                        },
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
