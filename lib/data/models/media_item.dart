import '../../core/config/tmdb_config.dart';

enum MediaType { movie, tv }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.localizedTitle,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.voteAverage,
    required this.releaseDate,
    required this.genreIds,
    required this.mediaType,
    this.runtime,
    this.imdbId,
    this.certification,
    this.tvSeasons,
  });

  final int id;
  final String title; // original_title / original_name
  final String localizedTitle; // title / name (pt-BR)
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String releaseDate;
  final List<int> genreIds;
  final MediaType mediaType;
  final String? tagline;
  final int? runtime;
  final String? imdbId;
  final String? certification;
  final List<TvSeason>? tvSeasons;

  String get posterUrl => TmdbConfig.poster(posterPath);
  String get backdropUrl => TmdbConfig.backdrop(backdropPath);

  String get year => releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';

  factory MediaItem.fromJson(Map<String, dynamic> json, {MediaType? forceType}) {
    final isTv = forceType == MediaType.tv ||
        (forceType == null && (json['media_type'] == 'tv' || json.containsKey('first_air_date')));

    String? cert;
    if (isTv) {
      final results = json['content_ratings']?['results'] as List<dynamic>?;
      if (results != null) {
        final br = results.firstWhere((r) => r['iso_3166_1'] == 'BR', orElse: () => null);
        if (br != null && br['rating'] != null && br['rating'].toString().isNotEmpty) {
          cert = br['rating'].toString();
        } else {
          final us = results.firstWhere((r) => r['iso_3166_1'] == 'US', orElse: () => null);
          if (us != null && us['rating'] != null && us['rating'].toString().isNotEmpty) {
            cert = us['rating'].toString();
          }
        }
      }
    } else {
      final results = json['release_dates']?['results'] as List<dynamic>?;
      if (results != null) {
        final br = results.firstWhere((r) => r['iso_3166_1'] == 'BR', orElse: () => null);
        if (br != null) {
          final dates = br['release_dates'] as List<dynamic>?;
          if (dates != null && dates.isNotEmpty && dates.first['certification'].toString().isNotEmpty) {
            cert = dates.first['certification'].toString();
          }
        }
        if (cert == null) {
          final us = results.firstWhere((r) => r['iso_3166_1'] == 'US', orElse: () => null);
          if (us != null) {
            final dates = us['release_dates'] as List<dynamic>?;
            if (dates != null && dates.isNotEmpty && dates.first['certification'].toString().isNotEmpty) {
              cert = dates.first['certification'].toString();
            }
          }
        }
      }
    }

    List<TvSeason>? tvSeasons;
    if (isTv && json['seasons'] != null) {
      final seasonsList = json['seasons'] as List<dynamic>;
      tvSeasons = seasonsList.map((e) {
        final seasonMap = e as Map<String, dynamic>;
        return TvSeason(
          seasonNumber: seasonMap['season_number'] as int? ?? 0,
          episodeCount: seasonMap['episode_count'] as int? ?? 0,
          name: seasonMap['name'] as String? ?? 'Temporada ${seasonMap['season_number']}',
        );
      }).where((s) => s.seasonNumber > 0 && s.episodeCount > 0).toList();
    }

    return MediaItem(
      id: json['id'] as int,
      title: (isTv ? json['original_name'] : json['original_title']) as String? ??
          json['name'] as String? ??
          json['title'] as String? ??
          '',
      localizedTitle: (isTv ? json['name'] : json['title']) as String? ?? '',
      overview: json['overview'] as String? ?? '',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      releaseDate: (isTv ? json['first_air_date'] : json['release_date']) as String? ?? '',
      genreIds: (json['genre_ids'] as List<dynamic>?)?.cast<int>() ??
          (json['genres'] as List<dynamic>?)
              ?.map((g) => g['id'] as int)
              .toList() ??
          const [],
      mediaType: isTv ? MediaType.tv : MediaType.movie,
      tagline: json['tagline'] as String?,
      runtime: json['runtime'] as int? ??
          ((json['episode_run_time'] as List<dynamic>?)?.isNotEmpty == true
              ? (json['episode_run_time'] as List<dynamic>).first as int
              : null),
      imdbId: json['external_ids']?['imdb_id'] as String? ?? json['imdb_id'] as String?,
      certification: cert,
      tvSeasons: tvSeasons,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'name': localizedTitle, // we map back so localizedTitle goes here
      'overview': overview,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'vote_average': voteAverage,
      'release_date': releaseDate,
      'genre_ids': genreIds,
      'media_type': mediaType.name,
      'tagline': tagline,
      'runtime': runtime,
      'imdb_id': imdbId,
      // store certification as a dummy content_ratings to parse it back
      if (certification != null)
        'content_ratings': {
          'results': [
            {'iso_3166_1': 'BR', 'rating': certification}
          ]
        },
    };
  }
}

class CastMember {
  const CastMember({required this.name, required this.character, this.profilePath});

  final String name;
  final String character;
  final String? profilePath;

  String get profileUrl => TmdbConfig.poster(profilePath, size: 'w185');

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      name: json['name'] as String? ?? '',
      character: json['character'] as String? ?? '',
      profilePath: json['profile_path'] as String?,
    );
  }
}

class TvSeason {
  const TvSeason({
    required this.seasonNumber,
    required this.episodeCount,
    required this.name,
  });

  final int seasonNumber;
  final int episodeCount;
  final String name;
}
