import 'dart:math';
import '../models/media_item.dart';
import 'tmdb_service.dart';
import 'watch_history_store.dart';

class RecommendationEngine {
  final TmdbService _tmdb;

  RecommendationEngine(this._tmdb);

  /// Retorna as recomendações personalizadas com base no histórico do usuário.
  Future<List<MediaItem>> getRecommendations() async {
    await WatchHistoryStore.instance.ensureLoaded();
    final history = WatchHistoryStore.instance.sortedEntries;

    if (history.isEmpty) {
      return []; // Cold start puro, a HomeScreen pode ocultar a prateleira.
    }

    // 1. Calcula o peso de cada item no histórico
    // Peso = Progresso (0.0 a 1.0) * Fator de Decaimento de Tempo (Itens mais recentes valem mais)
    final now = DateTime.now().millisecondsSinceEpoch;
    const maxDecayDays = 30.0;
    
    Map<int, double> genreWeights = {};
    ContinueWatchingEntry? bestItem;
    double bestItemScore = -1.0;

    for (var entry in history) {
      final daysOld = (now - entry.timestamp) / (1000 * 60 * 60 * 24);
      final decay = max(0.2, 1.0 - (daysOld / maxDecayDays)); // Mínimo de 0.2 de peso para coisas antigas
      
      // Filmes abertos e logo fechados (progresso < 5%) tem peso quase nulo.
      final progress = entry.progress;
      if (progress < 0.05) continue; 

      final score = progress * decay;

      // Acha o melhor item para usar como âncora do endpoint "Similar"
      if (score > bestItemScore) {
        bestItemScore = score;
        bestItem = entry;
      }

      // Soma os pesos para os gêneros deste item
      for (var genreId in entry.item.genreIds) {
        genreWeights[genreId] = (genreWeights[genreId] ?? 0.0) + score;
      }
    }

    if (bestItem == null) return [];

    // 2. Extrai os gêneros favoritos
    final sortedGenres = genreWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topGenreIds = sortedGenres.take(3).map((e) => e.key).toList();

    // 3. Chamadas paralelas à API do TMDB para recomendações
    final futures = <Future<List<MediaItem>>>[];

    // Busca filmes similares ao melhor filme/série assistido
    futures.add(_tmdb.similar(bestItem.item.id, bestItem.item.mediaType));

    // Busca descobrir conteúdos misturando os top gêneros
    if (topGenreIds.isNotEmpty) {
      final genreQuery = topGenreIds.join(',');
      futures.add(_tmdb.discoverByGenreString(genreQuery, type: MediaType.movie));
      futures.add(_tmdb.discoverByGenreString(genreQuery, type: MediaType.tv));
    }

    // Aguarda e mescla
    final results = await Future.wait(futures);
    final allItems = results.expand((i) => i).toList();

    // 4. Desduplicação e Filtragem
    // Remove itens que o usuário já assistiu bastante (progresso > 80%)
    final watchedIds = history.where((e) => e.progress > 0.8).map((e) => e.item.id).toSet();
    
    final uniqueItems = <int, MediaItem>{};
    for (var item in allItems) {
      if (!watchedIds.contains(item.id)) {
        uniqueItems[item.id] = item;
      }
    }

    // Embaralha para dar uma sensação orgânica (não ficar sempre igual se nada mudar)
    final finalList = uniqueItems.values.toList()..shuffle(Random());
    
    // Retorna os top 20
    return finalList.take(20).toList();
  }
}
