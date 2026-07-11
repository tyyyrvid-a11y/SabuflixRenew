class TmdbConfig {
  TmdbConfig._();

  static const String apiKey = 'ee0794f59f93b7a056bb76ef52dc28d0';
  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBase = 'https://image.tmdb.org/t/p';

  static const String language = 'pt-BR';

  static String poster(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return '';
    return '$imageBase/$size$path';
  }

  static String backdrop(String? path, {String size = 'w1280'}) {
    if (path == null || path.isEmpty) return '';
    return '$imageBase/$size$path';
  }
}
