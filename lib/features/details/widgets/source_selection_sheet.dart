import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/glass/glass_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/media_item.dart';
import '../../../data/services/stream_resolver.dart';
import '../../player/video_player_screen.dart';

class SourceSelectionSheet extends StatefulWidget {
  const SourceSelectionSheet({
    super.key,
    required this.item,
    required this.forDownload,
    this.season = 1,
    this.episode = 1,
  });

  final MediaItem item;
  final bool forDownload;
  final int season;
  final int episode;

  @override
  State<SourceSelectionSheet> createState() => _SourceSelectionSheetState();
}

class _SourceSelectionSheetState extends State<SourceSelectionSheet> {
  late Future<List<ResolvedStream>> _future;

  @override
  void initState() {
    super.initState();
    _future = StreamResolver.resolve(
      widget.item, 
      season: widget.season, 
      episode: widget.episode,
    );
  }

  void _onStreamSelected(ResolvedStream stream) async {
    if (widget.forDownload || stream.isExternal) {
      final url = Uri.parse(stream.url);
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível abrir o navegador.')),
          );
        }
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
              item: widget.item,
              resolvedStream: stream, // Modificaremos o VideoPlayerScreen para aceitar isto
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.forDownload ? 'Fontes para Download' : 'Fontes de Streaming',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              GlassIconButton(
                icon: CupertinoIcons.xmark,
                size: 32,
                iconSize: 16,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<ResolvedStream>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoActivityIndicator(radius: 16, color: AppColors.accent),
                        SizedBox(height: 16),
                        Text('Buscando fontes em múltiplos add-ons...', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      'Erro ao buscar fontes.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                );
              }

              final streams = snapshot.data ?? [];
              if (streams.isEmpty) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text('Nenhuma fonte encontrada.', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                );
              }

              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: ListView.separated(
                  itemCount: streams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final stream = streams[index];
                    return InkWell(
                      onTap: () => _onStreamSelected(stream),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.play_circle_fill, size: 40, color: AppColors.accent),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stream.name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stream.title,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
