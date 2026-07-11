import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

class ResolvedStream {
  final String url;
  final String name;
  final String title;
  final Map<String, String>? headers;
  final bool isExternal;

  ResolvedStream({
    required this.url,
    required this.name,
    required this.title,
    this.headers,
    this.isExternal = false,
  });
}

class StreamResolver {
  StreamResolver._();

  static Future<List<ResolvedStream>> resolve(MediaItem item) async {
    if (item.imdbId == null || item.imdbId!.isEmpty) {
      throw Exception('IMDB ID não encontrado.');
    }

    final imdbId = item.imdbId!;
    // Por enquanto, sempre usamos '/movie' já que não temos suporte a temporadas/episódios na UI.
    // Se precisarmos de séries no futuro, será '/series/$imdbId:$season:$episode.json'.

    final endpoints = [
      'https://kingvod.wasmer.app/index.php/stream/movie/$imdbId.json',
      'https://froststream.cloutteam.com/stream/movie/$imdbId.json',
    ];

    final futures = endpoints.map((endpoint) => _fetchStreams(endpoint));
    final results = await Future.wait(futures);

    // Flatten lists and remove nulls
    final allStreams = results.expand((element) => element).toList();

    if (allStreams.isEmpty) {
      throw Exception('Nenhuma stream encontrada em nenhuma fonte.');
    }

    if (item.mediaType == MediaType.movie) {
      allStreams.add(ResolvedStream(
        url: 'https://mgeb.top/embed/${item.id}',
        name: 'Razer',
        title: 'Assistir pelo navegador (Streaming Externo)',
        isExternal: true,
      ));
    }

    return allStreams;
  }

  static Future<List<ResolvedStream>> _fetchStreams(String endpoint) async {
    try {
      final uri = Uri.parse(endpoint);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final streams = data['streams'] as List<dynamic>? ?? [];

      return streams.map((s) {
        final streamMap = s as Map<String, dynamic>;
        final streamUrl = streamMap['url'] as String?;
        if (streamUrl == null) return null;

        Map<String, String>? headers;
        final behaviorHints = streamMap['behaviorHints'] as Map<String, dynamic>?;
        if (behaviorHints != null) {
          final proxyHeaders = behaviorHints['proxyHeaders'] as Map<String, dynamic>?;
          if (proxyHeaders != null) {
            final requestHeaders = proxyHeaders['request'] as Map<String, dynamic>?;
            if (requestHeaders != null) {
              headers = requestHeaders.map((key, value) => MapEntry(key, value.toString()));
            }
          }
        }

        final name = (streamMap['name'] ?? 'Desconhecido') as String;
        final title = (streamMap['title'] ?? '') as String;

        // Limpar um pouco o título removendo quebras de linha em excesso se quiser
        // final cleanTitle = title.replaceAll('\n', ' • ');

        return ResolvedStream(
          url: streamUrl,
          name: name,
          title: title.replaceAll('\n', ' • '),
          headers: headers,
        );
      }).where((s) => s != null).cast<ResolvedStream>().toList();
    } catch (e) {
      return []; // Falha silenciosa para esta fonte
    }
  }
}
