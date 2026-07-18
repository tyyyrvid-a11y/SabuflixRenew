import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/tmdb_config.dart';
import '../models/genre.dart';
import '../models/media_item.dart';

class TmdbService {
  TmdbService();

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    final params = {
      'api_key': TmdbConfig.apiKey,
      'language': TmdbConfig.language,
      ...?query,
    };
    final uri = Uri.parse('${TmdbConfig.baseUrl}$path').replace(queryParameters: params);
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('TMDB error ${response.statusCode}: ${response.body}');
    }
    return json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  List<MediaItem> _parseList(Map<String, dynamic> data, {MediaType? forceType}) {
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .map((e) => MediaItem.fromJson(e as Map<String, dynamic>, forceType: forceType))
        .where((m) => m.posterPath != null || m.backdropPath != null)
        .toList();
  }

  Future<List<MediaItem>> trending({String mediaType = 'all', String window = 'week'}) async {
    final data = await _get('/trending/$mediaType/$window');
    return _parseList(data);
  }

  Future<List<MediaItem>> popularMovies() async {
    final data = await _get('/movie/popular');
    return _parseList(data, forceType: MediaType.movie);
  }

  Future<List<MediaItem>> topRatedMovies() async {
    final data = await _get('/movie/top_rated');
    return _parseList(data, forceType: MediaType.movie);
  }

  Future<List<MediaItem>> nowPlayingMovies() async {
    final data = await _get('/movie/now_playing');
    return _parseList(data, forceType: MediaType.movie);
  }

  Future<List<MediaItem>> popularTv() async {
    final data = await _get('/tv/popular');
    return _parseList(data, forceType: MediaType.tv);
  }

  Future<List<MediaItem>> topRatedTv() async {
    final data = await _get('/tv/top_rated');
    return _parseList(data, forceType: MediaType.tv);
  }

  Future<List<Genre>> movieGenres() async {
    final data = await _get('/genre/movie/list');
    final genres = data['genres'] as List<dynamic>? ?? [];
    return genres.map((e) => Genre.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<MediaItem>> discoverByGenre(int genreId, {MediaType type = MediaType.movie}) async {
    final path = type == MediaType.movie ? '/discover/movie' : '/discover/tv';
    final data = await _get(path, {'with_genres': '$genreId', 'sort_by': 'popularity.desc'});
    return _parseList(data, forceType: type);
  }

  Future<List<MediaItem>> discoverByGenreString(String genreIds, {MediaType type = MediaType.movie}) async {
    final path = type == MediaType.movie ? '/discover/movie' : '/discover/tv';
    final data = await _get(path, {'with_genres': genreIds, 'sort_by': 'popularity.desc'});
    return _parseList(data, forceType: type);
  }

  Future<List<MediaItem>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/search/multi', {'query': query, 'include_adult': 'false'});
    return _parseList(data);
  }

  Future<MediaItem> details(int id, MediaType type) async {
    final path = type == MediaType.movie ? '/movie/$id' : '/tv/$id';
    final data = await _get(path, {'append_to_response': 'external_ids,release_dates,content_ratings'});
    return MediaItem.fromJson(data, forceType: type);
  }

  Future<List<CastMember>> cast(int id, MediaType type) async {
    final path = type == MediaType.movie ? '/movie/$id/credits' : '/tv/$id/credits';
    final data = await _get(path);
    final castList = data['cast'] as List<dynamic>? ?? [];
    return castList
        .take(12)
        .map((e) => CastMember.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MediaItem>> similar(int id, MediaType type) async {
    final path = type == MediaType.movie ? '/movie/$id/similar' : '/tv/$id/similar';
    final data = await _get(path);
    return _parseList(data, forceType: type);
  }
}
