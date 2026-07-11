import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/glass/glass_container.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/media_item.dart';
import '../../data/services/tmdb_service.dart';
import '../details/details_screen.dart';
import '../home/widgets/poster_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _service = TmdbService();
  final _controller = TextEditingController();
  Timer? _debounce;
  List<MediaItem> _results = [];
  bool _loading = false;
  bool _searched = false;

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final results = await _service.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: GlassContainer(
                borderRadius: 18,
                blurSigma: 20,
                tintOpacity: 0.10,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: _onChanged,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                        cursorColor: AppColors.accent,
                        decoration: const InputDecoration(
                          hintText: 'Buscar filmes e séries',
                          hintStyle: TextStyle(color: AppColors.textTertiary),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _controller.clear();
                          _onChanged('');
                        },
                        child: const Icon(Icons.close_rounded, color: AppColors.textTertiary, size: 20),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_searched) {
      return const Center(
        child: Text('Encontre filmes e séries no catálogo TMDB', style: TextStyle(color: AppColors.textTertiary)),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text('Nenhum resultado encontrado', style: TextStyle(color: AppColors.textTertiary)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.52,
      ),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final item = _results[i];
        return PosterCard(
          item: item,
          width: double.infinity,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DetailsScreen(item: item)),
          ),
        );
      },
    );
  }
}
