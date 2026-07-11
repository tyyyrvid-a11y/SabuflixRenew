import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/glass/glass_button.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/media_item.dart';
import '../../data/services/my_list_store.dart';
import '../../data/services/stream_resolver.dart';
import '../../data/services/tmdb_service.dart';
import '../home/widgets/media_row.dart';
import 'widgets/source_selection_sheet.dart';

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key, required this.item});

  final MediaItem item;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final _service = TmdbService();
  late Future<_DetailsData> _future;
  final _myList = MyListStore.instance;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DetailsData> _load() async {
    final results = await Future.wait([
      _service.details(widget.item.id, widget.item.mediaType),
      _service.cast(widget.item.id, widget.item.mediaType),
      _service.similar(widget.item.id, widget.item.mediaType),
    ]);
    return _DetailsData(
      details: results[0] as MediaItem,
      cast: results[1] as List<CastMember>,
      similar: results[2] as List<MediaItem>,
    );
  }

  void _showSourceSelection(MediaItem item, bool forDownload) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SourceSelectionSheet(item: item, forDownload: forDownload),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<_DetailsData>(
        future: _future,
        builder: (context, snapshot) {
          final loaded = snapshot.connectionState == ConnectionState.done && snapshot.hasData;
          final details = loaded ? snapshot.data!.details : widget.item;
          final cast = loaded ? snapshot.data!.cast : const <CastMember>[];
          final similar = loaded ? snapshot.data!.similar : const <MediaItem>[];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    _Backdrop(url: details.backdropUrl),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      left: 20,
                      child: GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details.title,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.6,
                          height: 1.05,
                        ),
                      ),
                      if (details.localizedTitle.isNotEmpty && details.localizedTitle != details.title) ...[
                        const SizedBox(height: 4),
                        Text(
                          details.localizedTitle,
                          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _MetaRow(item: details),
                      if (details.tagline != null && details.tagline!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          details.tagline!,
                          style: const TextStyle(fontSize: 14, color: AppColors.accentTeal, fontStyle: FontStyle.italic),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: GlassButton(
                              label: 'Assistir',
                              icon: Icons.play_arrow_rounded,
                              style: GlassButtonStyle.filled,
                              onTap: () => _showSourceSelection(details, false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          AnimatedBuilder(
                            animation: _myList,
                            builder: (context, _) {
                              final saved = _myList.contains(details);
                              return GlassIconButton(
                                icon: saved ? Icons.check_rounded : Icons.add_rounded,
                                onTap: () => _myList.toggle(details),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          GlassIconButton(
                            icon: Icons.download_rounded,
                            onTap: () => _showSourceSelection(details, true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        details.overview.isNotEmpty ? details.overview : 'Sinopse não disponível.',
                        style: const TextStyle(fontSize: 14.5, color: AppColors.textSecondary, height: 1.5),
                      ),
                      if (!loaded) ...[
                        const SizedBox(height: 30),
                        const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                      ],
                      if (cast.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const Text(
                          'Elenco',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        _CastList(cast: cast),
                      ],
                    ],
                  ),
                ),
              ),
              if (similar.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: MediaRow(
                      title: 'Títulos parecidos',
                      items: similar,
                      onItemTap: (m) => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => DetailsScreen(item: m)),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          url.isEmpty
              ? Container(color: AppColors.surface)
              : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppColors.heroScrim,
                stops: [0.3, 0.75, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (item.year.isNotEmpty) item.year,
      if (item.runtime != null && item.runtime! > 0) '${item.runtime} min',
      item.mediaType == MediaType.movie ? 'Filme' : 'Série',
    ];
    return Row(
      children: [
        if (item.certification != null && item.certification!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24, width: 0.5),
            ),
            child: Text(
              item.certification!,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (item.voteAverage > 0) ...[
          const Icon(Icons.star_rounded, size: 16, color: AppColors.accentTeal),
          const SizedBox(width: 4),
          Text(item.voteAverage.toStringAsFixed(1),
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            parts.join('  ·  '),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}

class _CastList extends StatelessWidget {
  const _CastList({required this.cast});
  final List<CastMember> cast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cast.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final member = cast[i];
          return SizedBox(
            width: 78,
            child: Column(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: member.profileUrl.isEmpty
                        ? Container(
                            color: AppColors.surface,
                            child: const Icon(Icons.person, color: AppColors.textTertiary),
                          )
                        : CachedNetworkImage(imageUrl: member.profileUrl, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailsData {
  _DetailsData({required this.details, required this.cast, required this.similar});
  final MediaItem details;
  final List<CastMember> cast;
  final List<MediaItem> similar;
}
