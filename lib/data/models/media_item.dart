import '../../core/utils.dart';

enum MediaKind { live, movie, series }

/// Um servidor (fonte) alternativo para o mesmo canal/filme/episódio.
class StreamServer {
  const StreamServer({required this.url, this.name, this.headers});

  final String url;
  final String? name;
  final Map<String, String>? headers;

  String get label {
    final value = name?.trim();
    if (value == null || value.isEmpty) return 'Servidor';
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        if (name != null) 'name': name,
        if (headers != null) 'headers': headers,
      };

  factory StreamServer.fromJson(Map<String, dynamic> json) {
    return StreamServer(
      url: (json['url'] as String?) ?? '',
      name: json['name'] as String?,
      headers: (json['headers'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())),
    );
  }
}

MediaKind mediaKindFromName(String value) {
  switch (value) {
    case 'movie':
      return MediaKind.movie;
    case 'series':
      return MediaKind.series;
    default:
      return MediaKind.live;
  }
}

String mediaKindToName(MediaKind kind) => kind.name;

class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.streamUrl,
    required this.kind,
    required this.sourceId,
    this.logo,
    this.group,
    this.tvgId,
    this.description,
    this.seriesTitle,
    this.season,
    this.episode,
    this.year,
    this.rating,
    this.backdrop,
    this.headers,
    this.alternateStreams,
    this.servers,
  });

  final String id;
  final String title;
  final String streamUrl;
  final MediaKind kind;
  final String sourceId;
  final String? logo;
  final String? group;
  final String? tvgId;
  final String? description;
  final String? seriesTitle;
  final int? season;
  final int? episode;
  final int? year;
  final double? rating;
  final String? backdrop;
  final Map<String, String>? headers;
  final List<String>? alternateStreams;
  final List<StreamServer>? servers;

  /// Lista normalizada de servidores disponíveis para este item.
  ///
  /// O primeiro é sempre o link principal; os demais vêm de
  /// `alternateStreams`/`servers`.
  List<StreamServer> get streamServers {
    final list = <StreamServer>[];

    void add(StreamServer server) {
      final url = server.url.trim();
      if (url.isEmpty) return;
      if (list.any((existing) => existing.url == url)) return;
      list.add(StreamServer(url: url, name: server.name, headers: server.headers));
    }

    final declared = servers;
    if (declared != null && declared.isNotEmpty) {
      for (final server in declared) {
        add(server);
      }
      if (!list.any((server) => server.url == streamUrl)) {
        add(StreamServer(url: streamUrl, headers: headers));
      }
    } else {
      add(StreamServer(url: streamUrl, headers: headers));
      for (final url in alternateStreams ?? const <String>[]) {
        add(StreamServer(url: url, headers: headers));
      }
    }

    return list;
  }

  String get displayGroup {
    final value = group?.trim();
    if (value == null || value.isEmpty) {
      return switch (kind) {
        MediaKind.live => 'Canais',
        MediaKind.movie => 'Filmes',
        MediaKind.series => 'Séries',
      };
    }
    return value;
  }

  String get seriesKey => '${normalizeText(seriesTitle ?? title)}|${normalizeText(displayGroup)}';

  String get episodeLabel {
    if (kind != MediaKind.series) return '';
    final s = season;
    final e = episode;
    if (s == null && e == null) return '';
    if (s != null && e != null) return 'T${s.toString().padLeft(2, '0')} E${e.toString().padLeft(2, '0')}';
    if (e != null) return 'E${e.toString().padLeft(2, '0')}';
    return 'T${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'streamUrl': streamUrl,
        'kind': kind.name,
        'sourceId': sourceId,
        'logo': logo,
        'group': group,
        'tvgId': tvgId,
        'description': description,
        'seriesTitle': seriesTitle,
        'season': season,
        'episode': episode,
        'year': year,
        'rating': rating,
        'backdrop': backdrop,
        if (headers != null) 'headers': headers,
        if (alternateStreams != null) 'alternateStreams': alternateStreams,
        if (servers != null) 'servers': servers!.map((server) => server.toJson()).toList(),
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      streamUrl: (json['streamUrl'] as String?) ?? '',
      kind: mediaKindFromName((json['kind'] as String?) ?? 'live'),
      sourceId: (json['sourceId'] as String?) ?? '',
      logo: json['logo'] as String?,
      group: json['group'] as String?,
      tvgId: json['tvgId'] as String?,
      description: json['description'] as String?,
      seriesTitle: json['seriesTitle'] as String?,
      season: json['season'] as int?,
      episode: json['episode'] as int?,
      year: json['year'] as int?,
      rating: (json['rating'] as num?)?.toDouble(),
      backdrop: json['backdrop'] as String?,
      headers: (json['headers'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())),
      alternateStreams: (json['alternateStreams'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      servers: (json['servers'] as List<dynamic>?)
          ?.map((e) => StreamServer.fromJson(e as Map<String, dynamic>))
          .where((server) => server.url.isNotEmpty)
          .toList(),
    );
  }
}

class SeriesGroup {
  const SeriesGroup({
    required this.key,
    required this.title,
    required this.group,
    required this.episodes,
    this.logo,
  });

  final String key;
  final String title;
  final String group;
  final List<MediaItem> episodes;
  final String? logo;

  MediaItem get poster => episodes.first;

  String get posterUrl {
    if (logo != null && logo!.isNotEmpty) return logo!;
    return episodes.first.logo ?? '';
  }

  int get seasonCount {
    final seasons = episodes.map((e) => e.season).whereType<int>().toSet();
    return seasons.isEmpty ? 1 : seasons.length;
  }
}

/// Representa a série como um item de catálogo (para usar nos cards/rows).
MediaItem seriesGroupAsItem(SeriesGroup group) {
  return MediaItem(
    id: group.key,
    title: group.title,
    streamUrl: group.poster.streamUrl,
    kind: MediaKind.series,
    sourceId: group.poster.sourceId,
    logo: group.logo,
    group: group.group,
    description: group.poster.description,
  );
}
