import 'dart:ui';
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
              resolvedStream: stream,
            ),
          ),
        );
      }
    }
  }

  List<Widget> _buildTags(String title) {
    final tags = <Widget>[];
    final lowerTitle = title.toLowerCase();

    // Resolução
    if (lowerTitle.contains('4k') || lowerTitle.contains('2160p')) {
      tags.add(const _Badge(text: '4K UHD', color: Colors.amber));
    } else if (lowerTitle.contains('1080p') || lowerTitle.contains('fhd')) {
      tags.add(const _Badge(text: '1080p FHD', color: Colors.blueAccent));
    } else if (lowerTitle.contains('720p') || lowerTitle.contains('hd')) {
      tags.add(const _Badge(text: '720p HD', color: Colors.teal));
    } else if (lowerTitle.contains('480p') || lowerTitle.contains('sd')) {
      tags.add(const _Badge(text: '480p SD', color: Colors.grey));
    }

    // Idioma / Áudio
    if (lowerTitle.contains('dublado') || lowerTitle.contains('pt-br') || lowerTitle.contains('nacional')) {
      tags.add(const _Badge(text: 'DUBLADO', color: Colors.green));
    } else if (lowerTitle.contains('legendado') || lowerTitle.contains('leg')) {
      tags.add(const _Badge(text: 'LEGENDADO', color: Colors.deepPurpleAccent));
    }

    // Tamanho (Ex: 1.5 GB ou 800 MB)
    final sizeMatch = RegExp(r'(\d+(?:\.\d+)?\s*(?:gb|mb))', caseSensitive: false).firstMatch(title);
    if (sizeMatch != null) {
      tags.add(_Badge(text: sizeMatch.group(1)!.toUpperCase(), color: Colors.white24, isOutline: true));
    }

    return tags;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: AppColors.background.withOpacity(0.85),
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.forDownload ? 'Fontes para Download' : 'Escolha a Qualidade',
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
                ),
                const SizedBox(height: 16),
                
                Flexible(
                  child: FutureBuilder<List<ResolvedStream>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 250,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CupertinoActivityIndicator(radius: 16, color: AppColors.accent),
                                SizedBox(height: 16),
                                Text('Analisando servidores globais...', style: TextStyle(color: AppColors.textSecondary)),
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
                            child: Text('Nenhuma fonte encontrada no momento.', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                        );
                      }

                      return SafeArea(
                        bottom: true,
                        top: false,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          shrinkWrap: true,
                          itemCount: streams.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final stream = streams[index];
                            final tags = _buildTags(stream.title);

                            return InkWell(
                              onTap: () => _onStreamSelected(stream),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: stream.isExternal ? Colors.orange.withOpacity(0.2) : AppColors.accent.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        stream.isExternal ? CupertinoIcons.link : CupertinoIcons.play_fill, 
                                        size: 24, 
                                        color: stream.isExternal ? Colors.orange : AppColors.accent
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            stream.name,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          if (tags.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: tags,
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Text(
                                            stream.title,
                                            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3), height: 1.3),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, this.isOutline = false});
  final String text;
  final Color color;
  final bool isOutline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOutline ? Colors.transparent : color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isOutline ? color : Colors.transparent, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isOutline ? Colors.white70 : color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
