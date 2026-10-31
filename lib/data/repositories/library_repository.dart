import 'package:flutter/services.dart' show rootBundle;
import '../demo_content.dart';
import '../models/epg_program.dart';
import '../models/media_item.dart';
import '../models/playlist_source.dart';
import '../parsers/m3u_parser.dart';
import '../parsers/xmltv_parser.dart';
import '../parsers/saimo_tv_parser.dart';
import '../parsers/saimo_vod_parser.dart';
import '../parsers/json_epg_parser.dart';
import '../services/http_service.dart';

class SourceLoadResult {
  const SourceLoadResult({
    required this.source,
    required this.items,
    this.error,
  });

  final PlaylistSource source;
  final List<MediaItem> items;
  final String? error;

  bool get ok => error == null;
}

class LibraryRepository {
  LibraryRepository({HttpService? http}) : _http = http ?? HttpService();

  final HttpService _http;

  Future<SourceLoadResult> loadSource(PlaylistSource source, {String? localContent}) async {
    try {
      if (source.url == 'asset://saimo/catalogo.txt') {
        final content = await rootBundle.loadString('assets/saimo/catalogo.txt');
        final items = SaimoTvParser.parse(content, sourceId: source.id);

        // Mapeamento de capas TMDB: fichas.txt cobre quase todo o catálogo.
        final Map<String, String> posters = {};
        String? destaquesContent;
        try {
          final fichasContent = await rootBundle.loadString('assets/saimo/vod_fichas.txt');
          posters.addAll(SaimoVodParser.parsePostersFromFichas(fichasContent));
        } catch (_) {}
        try {
          destaquesContent = await rootBundle.loadString('assets/saimo/destaques.txt');
          posters.addAll(SaimoVodParser.parsePostersFromDestaques(destaquesContent));
        } catch (_) {}

        final Map<String, String> streamsByTitle = {};

        // Carrega filmes atualizados do Saimo TV
        final filmeFiles = [
          'assets/saimo/filmes-A.txt',
          'assets/saimo/filmes-H.txt',
          'assets/saimo/filmes-L.txt',
          'assets/saimo/filmes-P.txt',
          'assets/saimo/filmes-V.txt',
        ];
        for (final file in filmeFiles) {
          try {
            final fContent = await rootBundle.loadString(file);
            final fItems = SaimoVodParser.parseFilmesFile(
              fContent,
              sourceId: source.id,
              postersByTitle: posters,
            );
            for (final f in fItems) {
              if (f.streamUrl.isNotEmpty) {
                streamsByTitle[f.title] = f.streamUrl;
                final clean = f.title.replaceAll(RegExp(r'\s*\(\d{4}\)$'), '').trim();
                streamsByTitle[clean] = f.streamUrl;
              }
            }
            items.addAll(fItems);
          } catch (_) {}
        }

        // Carrega séries atualizadas do Saimo TV
        final serieFiles = [
          'assets/saimo/series-A.txt',
          'assets/saimo/series-H.txt',
          'assets/saimo/series-L.txt',
          'assets/saimo/series-L-2.txt',
          'assets/saimo/series-P.txt',
          'assets/saimo/series-V.txt',
          'assets/saimo/series-V-1.txt',
        ];
        for (final file in serieFiles) {
          try {
            final sContent = await rootBundle.loadString(file);
            final sItems = SaimoVodParser.parseSeriesFile(
              sContent,
              sourceId: source.id,
              postersByTitle: posters,
            );
            for (final s in sItems) {
              if (s.seriesTitle != null && s.streamUrl.isNotEmpty) {
                streamsByTitle[s.seriesTitle!] = s.streamUrl;
                final clean = s.seriesTitle!.replaceAll(RegExp(r'\s*\(\d{4}\)$'), '').trim();
                streamsByTitle[clean] = s.streamUrl;
              }
            }
            items.addAll(sItems);
          } catch (_) {}
        }

        // Carrega acervo de animes com streaming direto
        try {
          final animesContent = await rootBundle.loadString('assets/saimo/redeflix/links-animes.txt');
          final animesItems = SaimoVodParser.parseSeriesLinks(
            animesContent,
            sourceId: source.id,
            defaultGroup: 'Séries | Animes',
            postersByTitle: posters,
          );
          for (final a in animesItems) {
            if (a.seriesTitle != null && a.streamUrl.isNotEmpty) {
              streamsByTitle[a.seriesTitle!] = a.streamUrl;
            }
          }
          items.addAll(animesItems);
        } catch (_) {}

        // Carrega acervo de doramas com streaming direto
        try {
          final doramasContent = await rootBundle.loadString('assets/saimo/redeflix/links-doramas.txt');
          final doramasItems = SaimoVodParser.parseSeriesLinks(
            doramasContent,
            sourceId: source.id,
            defaultGroup: 'Séries | Doramas',
            postersByTitle: posters,
          );
          for (final d in doramasItems) {
            if (d.seriesTitle != null && d.streamUrl.isNotEmpty) {
              streamsByTitle[d.seriesTitle!] = d.streamUrl;
            }
          }
          items.addAll(doramasItems);
        } catch (_) {}

        // Carrega destaques com os links de transmissão associados
        if (destaquesContent != null) {
          try {
            final destaquesItems = SaimoVodParser.parseDestaques(
              destaquesContent,
              sourceId: source.id,
              streamsByTitle: streamsByTitle,
            );
            items.addAll(destaquesItems);
          } catch (_) {}
        }

        return SourceLoadResult(source: source, items: items);
      }
      if (source.url == 'asset://saimo/restritos.txt') {
        final content = await rootBundle.loadString('assets/saimo/restritos.txt');
        final items = SaimoTvParser.parse(content, sourceId: source.id, isRestricted: true);
        return SourceLoadResult(source: source, items: items);
      }

      final content = localContent ??
          (source.url == demoPlaylistUrl ? demoPlaylistContent : await _http.getText(source.url));

      // Check if it's Saimo format or M3U
      if (content.contains('canal:') && content.contains('fonte:')) {
        final items = SaimoTvParser.parse(content, sourceId: source.id);
        return SourceLoadResult(source: source, items: items);
      }

      if (!content.contains('#EXTM3U') && !content.contains('#EXTINF')) {
        return SourceLoadResult(
          source: source,
          items: const [],
          error: 'O link não parece uma lista .m3u nem formato Saimo TV.',
        );
      }
      final parsed = M3uParser.parse(content, sourceId: source.id);
      return SourceLoadResult(source: source, items: parsed.items);
    } on HttpFailure catch (error) {
      return SourceLoadResult(source: source, items: const [], error: error.message);
    } catch (error) {
      return SourceLoadResult(source: source, items: const [], error: 'Erro inesperado: $error');
    }
  }

  Future<EpgGuide> loadEpg(String url) async {
    if (url == 'asset://saimo/guia.json') {
      final content = await rootBundle.loadString('assets/saimo/guia.json');
      return SaimoEpgParser.parse(content);
    }
    final content = await _http.getText(url);
    if (content.trim().startsWith('{')) {
      return SaimoEpgParser.parse(content);
    }
    return XmltvParser.parse(content);
  }

  void dispose() => _http.close();
}
