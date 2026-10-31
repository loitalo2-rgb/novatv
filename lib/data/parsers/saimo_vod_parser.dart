import '../../core/utils.dart';
import '../models/media_item.dart';

class SaimoVodParser {
  static final RegExp _urlPattern = RegExp(r'https?://[^\s,]+');
  static final RegExp _labelPattern = RegExp(r'^[A-Za-z]{2,14}$');
  static final RegExp _yearSuffix = RegExp(r'\s*\(\d{4}\)$');
  static final RegExp _extraSpaces = RegExp(r'\s+');

  /// Chave usada para casar títulos entre as listas de filmes/séries e as fichas.
  ///
  /// Ignora ano, acentos, pontuação e espaços extras para reduzir diferenças
  /// entre os arquivos (ex.: `A 13o Emenda` x `A 13ª Emenda`).
  static String posterKey(String value) {
    final clean = value.replaceAll(_yearSuffix, '').trim();
    var key = normalizeText(clean)
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(_extraSpaces, ' ')
        .trim();
    // "13o"/"5a" (ordinais escritos com letra) x "13ª"/"5ª" (símbolo).
    key = key
        .replaceAllMapped(RegExp(r'\b(\d+)[oa]\b'), (match) => match.group(1)!)
        .replaceAll(_extraSpaces, ' ')
        .trim();
    return key;
  }

  static void _putPoster(Map<String, String> posters, String title, String url) {
    final exact = title.trim();
    if (exact.isEmpty || url.isEmpty) return;
    posters.putIfAbsent(exact, () => url);
    posters.putIfAbsent(posterKey(title), () => url);
  }

  static String? _posterFor(Map<String, String>? posters, String title) {
    if (posters == null || posters.isEmpty) return null;
    return posters[title] ??
        posters[title.replaceAll(_yearSuffix, '').trim()] ??
        posters[posterKey(title)];
  }

  /// Separa links marcados por rótulo (ex.: `dub=...`, `leg=...`) em servidores.
  static List<StreamServer> _buildServers(String text, {String? defaultName}) {
    final servers = <StreamServer>[];

    for (final chunk in text.split('\t')) {
      var part = chunk.trim();
      if (part.isEmpty) continue;

      String? label;
      final equals = part.indexOf('=');
      if (equals > 0) {
        final candidate = part.substring(0, equals).trim();
        if (_labelPattern.hasMatch(candidate)) {
          label = candidate;
          part = part.substring(equals + 1);
        }
      }

      final urls = _urlPattern.allMatches(part).map((match) => match.group(0)!).toList();
      for (var index = 0; index < urls.length; index++) {
        final baseName = label ?? defaultName;
        final name = baseName == null || baseName.isEmpty
            ? null
            : (urls.length > 1 ? '$baseName ${index + 1}' : baseName);
        servers.add(StreamServer(url: urls[index], name: name));
      }
    }

    return servers;
  }

  /// Faz o parse dos arquivos de filmes (filmes-A.txt, etc.)
  static List<MediaItem> parseFilmesFile(
    String content, {
    required String sourceId,
    Map<String, String>? postersByTitle,
  }) {
    final List<MediaItem> items = [];
    final lines = content.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final tabIdx = line.indexOf('\t');
      if (tabIdx <= 0) continue;

      final title = line.substring(0, tabIdx).trim();
      final servers = _buildServers(line.substring(tabIdx + 1));
      if (servers.isEmpty) continue;

      final poster = _posterFor(postersByTitle, title);

      items.add(MediaItem(
        id: '$sourceId-filme-${title.replaceAll(' ', '_')}',
        title: title,
        streamUrl: servers.first.url,
        kind: MediaKind.movie,
        sourceId: sourceId,
        group: 'Filmes',
        logo: poster,
        alternateStreams: servers.length > 1 ? servers.skip(1).map((server) => server.url).toList() : null,
        servers: servers,
      ));
    }

    return items;
  }

  /// Faz o parse dos arquivos de séries padrão (series-A.txt, etc.)
  static List<MediaItem> parseSeriesFile(
    String content, {
    required String sourceId,
    Map<String, String>? postersByTitle,
  }) {
    final List<MediaItem> items = [];
    final lines = content.split('\n');

    String? currentTitle;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('@')) {
        currentTitle = line.substring(1).split('\t').first.trim();
      } else {
        if (currentTitle == null) continue;
        final parts = line.split('\t');
        if (parts.length >= 3) {
          final season = int.tryParse(parts[0].trim()) ?? 1;
          final episode = int.tryParse(parts[1].trim()) ?? 1;
          final servers = _buildServers(parts.skip(2).join('\t'));
          if (servers.isEmpty) continue;

          final poster = _posterFor(postersByTitle, currentTitle);
          final epTitle = '$currentTitle T$season:E$episode';

          items.add(MediaItem(
            id: '$sourceId-serie-${currentTitle.replaceAll(' ', '_')}-s${season}e$episode',
            title: epTitle,
            streamUrl: servers.first.url,
            kind: MediaKind.series,
            sourceId: sourceId,
            group: 'Séries',
            logo: poster,
            seriesTitle: currentTitle,
            season: season,
            episode: episode,
            alternateStreams: servers.length > 1 ? servers.skip(1).map((server) => server.url).toList() : null,
            servers: servers,
          ));
        }
      }
    }

    return items;
  }

  /// Faz o parse dos arquivos de animes e doramas com links diretos
  static List<MediaItem> parseSeriesLinks(
    String content, {
    required String sourceId,
    required String defaultGroup,
    Map<String, String>? postersByTitle,
  }) {
    final List<MediaItem> items = [];
    final lines = content.split('\n');

    String? currentTitle;
    String? currentYear;
    String? currentTmdbId;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('@')) {
        final parts = line.substring(1).split('\t');
        currentTitle = parts[0].trim();
        currentYear = parts.length > 1 && parts[1].trim().isNotEmpty ? parts[1].trim() : null;
        currentTmdbId = parts.length > 2 && parts[2].trim().isNotEmpty ? parts[2].trim() : null;
      } else {
        if (currentTitle == null) continue;
        final parts = line.split('\t');
        if (parts.length >= 4) {
          final season = int.tryParse(parts[0].trim()) ?? 1;
          final episode = int.tryParse(parts[1].trim()) ?? 1;
          final audio = parts[2].trim();
          final servers = _buildServers(
            parts.skip(3).join('\t'),
            defaultName: audio.isEmpty ? null : audio,
          );
          if (servers.isEmpty) continue;

          final poster = _posterFor(postersByTitle, currentTitle);
          final audioTag = audio.isNotEmpty ? ' [$audio]' : '';
          final epTitle = '$currentTitle T$season:E$episode$audioTag';

          items.add(MediaItem(
            id: '$sourceId-vod-${currentTitle.replaceAll(' ', '_')}-s${season}e$episode',
            title: epTitle,
            streamUrl: servers.first.url,
            kind: MediaKind.series,
            sourceId: sourceId,
            group: defaultGroup,
            logo: poster,
            seriesTitle: currentTitle,
            season: season,
            episode: episode,
            year: currentYear != null ? int.tryParse(currentYear) : null,
            tvgId: currentTmdbId,
            alternateStreams: servers.length > 1 ? servers.skip(1).map((server) => server.url).toList() : null,
            servers: servers,
          ));
        }
      }
    }

    return items;
  }

  /// Lê as capas e pôsteres de destaques.txt
  static Map<String, String> parsePostersFromDestaques(String content) {
    final Map<String, String> posters = {};
    final lines = content.split('\n');
    String baseUrl = 'https://image.tmdb.org/t/p/w342';

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('capa:')) {
        baseUrl = line.substring(5).trim();
        continue;
      }
      if (line.startsWith('fila\t')) continue;

      final parts = line.split('\t');
      if (parts.length >= 2) {
        final title = parts[1].trim();
        for (final p in parts) {
          if (p.startsWith('/') && (p.endsWith('.jpg') || p.endsWith('.png'))) {
            _putPoster(posters, title, '$baseUrl$p');
            break;
          }
        }
      }
    }

    return posters;
  }

  /// Lê as capas de todos os títulos em fichas.txt
  ///
  /// Formato: `tipo \t título \t idTMDB \t caminhoDoPôster \t gêneros`.
  static Map<String, String> parsePostersFromFichas(String content) {
    final Map<String, String> posters = {};
    final lines = content.split('\n');
    String baseUrl = 'https://image.tmdb.org/t/p/w342';

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('capa:')) {
        baseUrl = line.substring(5).trim();
        continue;
      }

      final parts = line.split('\t');
      if (parts.length < 4) continue;

      final title = parts[1].trim();
      final posterPath = parts[3].trim();
      if (title.isEmpty || !posterPath.startsWith('/')) continue;

      _putPoster(posters, title, '$baseUrl$posterPath');
    }

    return posters;
  }

  /// Lê os filmes e destaques da tela inicial
  static List<MediaItem> parseDestaques(
    String content, {
    required String sourceId,
    Map<String, String>? streamsByTitle,
  }) {
    final List<MediaItem> items = [];
    final lines = content.split('\n');
    String baseUrl = 'https://image.tmdb.org/t/p/w342';
    String currentFila = 'Em alta';

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('capa:')) {
        baseUrl = line.substring(5).trim();
        continue;
      }
      if (line.startsWith('fila\t')) {
        currentFila = line.substring(5).trim();
        continue;
      }

      final parts = line.split('\t');
      if (parts.length >= 2) {
        final type = parts[0].trim();
        final title = parts[1].trim();
        int? year;
        String? poster;

        for (final p in parts) {
          if (p.startsWith('/') && (p.endsWith('.jpg') || p.endsWith('.png'))) {
            poster = '$baseUrl$p';
          } else if (p.length == 4 && int.tryParse(p) != null) {
            year = int.tryParse(p);
          }
        }

        final isMovie = type == 'f';
        final isSeries = type == 's' || type == 'a' || type == 'd';

        if (isMovie || isSeries) {
          final cleanTitle = title.replaceAll(RegExp(r'\s*\(\d{4}\)$'), '').trim();
          final streamUrl = streamsByTitle?[title] ?? streamsByTitle?[cleanTitle] ?? '';

          items.add(MediaItem(
            id: '$sourceId-destaque-${title.replaceAll(' ', '_')}',
            title: title,
            streamUrl: streamUrl,
            kind: isMovie ? MediaKind.movie : MediaKind.series,
            sourceId: sourceId,
            group: 'Destaques | $currentFila',
            logo: poster,
            seriesTitle: isSeries ? title : null,
            year: year,
          ));
        }
      }
    }

    return items;
  }
}
