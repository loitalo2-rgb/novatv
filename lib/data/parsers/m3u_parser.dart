import '../../core/utils.dart';
import '../models/media_item.dart';

class M3uParseResult {
  const M3uParseResult({required this.items, this.skipped = 0});

  final List<MediaItem> items;
  final int skipped;
}

class M3uParser {
  const M3uParser._();

  static M3uParseResult parse(String content, {required String sourceId}) {
    final lines = content.split(RegExp(r'\r?\n'));
    final items = <MediaItem>[];
    final seen = <String>{};
    var skipped = 0;

    Map<String, String> attrs = const {};
    String? pendingTitle;
    String? pendingGroup;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        final info = _parseExtinf(line);
        attrs = info.attrs;
        pendingTitle = info.title;
        pendingGroup = attrs['group-title'];
        continue;
      }

      if (line.startsWith('#EXTGRP:')) {
        pendingGroup = line.substring('#EXTGRP:'.length).trim();
        continue;
      }

      if (line.startsWith('#')) {
        continue;
      }

      final title = pendingTitle;
      if (title == null || title.isEmpty) {
        skipped++;
        continue;
      }

      final streamUrl = line;
      if (!_looksLikeUrl(streamUrl)) {
        skipped++;
        pendingTitle = null;
        continue;
      }

      final group = (pendingGroup ?? attrs['group-title'] ?? '').trim();
      final kind = _classify(title: title, group: group, url: streamUrl, attrs: attrs);
      final episode = kind == MediaKind.series ? _parseEpisode(title) : const _EpisodeInfo(null, null, null);

      final cleanedTitle = cleanTitle(episode.baseTitle ?? title);
      final seriesTitle = episode.baseTitle != null ? cleanedTitle : cleanedTitle;
      final finalTitle = kind == MediaKind.series && episode.episode != null ? cleanedTitle : cleanedTitle;

      final id = stableId('$sourceId|$streamUrl|$title|$group');
      if (!seen.add(id)) {
        skipped++;
        pendingTitle = null;
        continue;
      }

      items.add(MediaItem(
        id: id,
        title: finalTitle.isEmpty ? title.trim() : finalTitle,
        streamUrl: streamUrl,
        kind: kind,
        sourceId: sourceId,
        logo: _firstNonEmpty([attrs['tvg-logo'], attrs['logo'], attrs['tvg-logo-small']]),
        group: group.isEmpty ? null : group,
        tvgId: _firstNonEmpty([attrs['tvg-id'], attrs['tvg-chno'], attrs['channel-id']]),
        description: _firstNonEmpty([attrs['description'], attrs['plot'], attrs['tvg-description']]),
        seriesTitle: kind == MediaKind.series ? seriesTitle : null,
        season: episode.season,
        episode: episode.episode,
        year: int.tryParse(attrs['year'] ?? '') ?? int.tryParse(attrs['release-year'] ?? ''),
        rating: double.tryParse(attrs['rating'] ?? ''),
      ));

      pendingTitle = null;
      pendingGroup = null;
      attrs = const {};
    }

    return M3uParseResult(items: items, skipped: skipped);
  }

  static bool _looksLikeUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return false;
    return const {'http', 'https', 'rtsp', 'rtmp', 'rtmps', 'udp'}.contains(uri.scheme.toLowerCase());
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static ({Map<String, String> attrs, String title}) _parseExtinf(String line) {
    final body = line.substring(line.indexOf(':') + 1);
    final comma = _firstCommaOutsideQuotes(body);
    final attrPart = comma >= 0 ? body.substring(0, comma) : body;
    final title = comma >= 0 ? body.substring(comma + 1).trim() : '';
    final attrs = <String, String>{};
    for (final match in RegExp(r'([A-Za-z0-9_-]+)\s*=\s*"([^"]*)"').allMatches(attrPart)) {
      attrs[match.group(1)!.toLowerCase()] = match.group(2)!.trim();
    }
    return (attrs: attrs, title: title);
  }

  static int _firstCommaOutsideQuotes(String value) {
    var inQuotes = false;
    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        return i;
      }
    }
    return -1;
  }

  static MediaKind _classify({
    required String title,
    required String group,
    required String url,
    required Map<String, String> attrs,
  }) {
    final declared = (attrs['tvg-type'] ?? attrs['type'] ?? attrs['media-type'] ?? '').toLowerCase();
    if (declared.contains('series')) return MediaKind.series;
    if (declared.contains('movie') || declared.contains('vod')) return MediaKind.movie;

    final haystack = normalizeText('$group $title');
    if (RegExp(r'\b(serie|series|anime|animes|dorama|doramas|novela|novelas|temporada|temporadas|sitcom|desenho|desenhos|infantil)\b')
        .hasMatch(haystack)) {
      return MediaKind.series;
    }
    if (RegExp(r'\b(filme|filmes|movie|movies|vod|cinema|documentario|documentarios|especial)\b').hasMatch(haystack)) {
      return MediaKind.movie;
    }
    final groupText = normalizeText(group);
    if (RegExp(r'\b(ao vivo|live|canais|canal|tv|noticias|esportes|esporte|radio|24h)\b').hasMatch(groupText)) {
      return MediaKind.live;
    }

    final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
    if (RegExp(r'\.(mp4|mkv|avi|mov|webm|m4v|mpg|mpeg)$').hasMatch(path)) {
      return MediaKind.movie;
    }
    return MediaKind.live;
  }

  static _EpisodeInfo _parseEpisode(String title) {
    final patterns = <RegExp>[
      RegExp(r'^(.*?)[\s._\-\[\]|]*[Tt](\d{1,3})[\s._\-]*[Ee](\d{1,4})(?:\b|$)', caseSensitive: false),
      RegExp(r'^(.*?)[\s._\-\[\]|]*[Ss](\d{1,3})[\s._\-]*[Ee](\d{1,4})(?:\b|$)', caseSensitive: false),
      RegExp(r'^(.*?)[\s._\-\[\]|]*(\d{1,2})[xX](\d{1,4})(?:\b|$)', caseSensitive: false),
      RegExp(r'^(.*?)[\s._\-\[\]|]*[Tt]emporada[\s._\-]*(\d{1,3}).*?[Ee]pis[oó]dio[\s._\-]*(\d{1,4})',
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(title);
      if (match == null) continue;
      final base = cleanTitle(match.group(1) ?? '');
      final season = int.tryParse(match.group(2) ?? '');
      final episode = int.tryParse(match.group(3) ?? '');
      if (base.isEmpty) continue;
      return _EpisodeInfo(base, season, episode);
    }
    return _EpisodeInfo(cleanTitle(title), null, null);
  }
}

class _EpisodeInfo {
  const _EpisodeInfo(this.baseTitle, this.season, this.episode);

  final String? baseTitle;
  final int? season;
  final int? episode;
}
