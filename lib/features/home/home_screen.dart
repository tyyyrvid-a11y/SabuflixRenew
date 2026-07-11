import 'package:flutter/material.dart';
import '../../core/glass/glass_button.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
import '../../data/mock/mock_data.dart';
import '../../data/models/media_item.dart';
import '../../data/services/tmdb_service.dart';
import '../../data/services/watch_history_store.dart';
import '../details/details_screen.dart';
import 'widgets/continue_watching_row.dart';
import 'widgets/hero_banner.dart';
import 'widgets/media_row.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = TmdbService();
  late Future<_HomeData> _future;
  final _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });
  }

  Future<_HomeData> _load() async {
    await WatchHistoryStore.instance.ensureLoaded();
    
    final results = await Future.wait([
      _service.trending(),
      _service.popularMovies(),
      _service.topRatedMovies(),
      _service.nowPlayingMovies(),
      _service.popularTv(),
      _service.discoverByGenre(28), // Action
      _service.discoverByGenre(35), // Comedy
    ]);

    final trending = results[0];
    final popularMovies = results[1];
    final topRated = results[2];
    final nowPlaying = results[3];
    final popularTv = results[4];
    final action = results[5];
    final comedy = results[6];

    final hero = trending.firstWhere(
      (m) => m.backdropPath != null,
      orElse: () => trending.first,
    );

    return _HomeData(
      hero: hero,
      trending: trending,
      popularMovies: popularMovies,
      topRated: topRated,
      nowPlaying: nowPlaying,
      popularTv: popularTv,
      action: action,
      comedy: comedy,
    );
  }

  void _openDetails(MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailsScreen(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorState(onRetry: () => setState(() => _future = _load()));
          }

          final data = snapshot.data!;
          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: HeroBanner(
                      item: data.hero,
                      onPlay: () => _openDetails(data.hero),
                      onInfo: () => _openDetails(data.hero),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: WatchHistoryStore.instance,
                            builder: (context, _) {
                              final history = WatchHistoryStore.instance.sortedEntries;
                              if (history.isEmpty) return const SizedBox.shrink();
                              return Column(
                                children: [
                                  ContinueWatchingRow(
                                    entries: history,
                                    onItemTap: _openDetails,
                                  ),
                                  const SizedBox(height: 28),
                                ],
                              );
                            },
                          ),
                          MediaRow(title: 'Em alta', items: data.trending, onItemTap: _openDetails),
                          const SizedBox(height: 28),
                          MediaRow(title: 'Populares', items: data.popularMovies, onItemTap: _openDetails),
                          const SizedBox(height: 28),
                          MediaRow(title: 'Séries populares', items: data.popularTv, onItemTap: _openDetails),
                          const SizedBox(height: 28),
                          MediaRow(title: 'Em cartaz', items: data.nowPlaying, onItemTap: _openDetails),
                          const SizedBox(height: 28),
                          MediaRow(title: 'Ação', items: data.action, onItemTap: _openDetails),
                          const SizedBox(height: 28),
                          MediaRow(title: 'Comédia', items: data.comedy, onItemTap: _openDetails),
                          const SizedBox(height: 28),
                          MediaRow(title: 'Mais bem avaliados', items: data.topRated, onItemTap: _openDetails),
                          const SizedBox(height: 110),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _TopBar(opacity: (_scrollOffset / 200).clamp(0, 1)),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.opacity});
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, bottom: 14, left: 20, right: 20),
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.85 * opacity),
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.06 * opacity)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const AppLogo(),
            GlassIconButton(icon: Icons.person_rounded, size: 38, iconSize: 18, onTap: () {}),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            const Text(
              'Não foi possível carregar o catálogo.\nVerifique sua conexão.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            GlassButton(label: 'Tentar novamente', icon: Icons.refresh_rounded, onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

class _HomeData {
  _HomeData({
    required this.hero,
    required this.trending,
    required this.popularMovies,
    required this.topRated,
    required this.nowPlaying,
    required this.popularTv,
    required this.action,
    required this.comedy,
  });

  final MediaItem hero;
  final List<MediaItem> trending;
  final List<MediaItem> popularMovies;
  final List<MediaItem> topRated;
  final List<MediaItem> nowPlaying;
  final List<MediaItem> popularTv;
  final List<MediaItem> action;
  final List<MediaItem> comedy;
}
