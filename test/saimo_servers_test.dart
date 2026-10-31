import 'package:flutter_test/flutter_test.dart';
import 'package:novatv/data/parsers/saimo_tv_parser.dart';
import 'package:novatv/data/parsers/saimo_vod_parser.dart';

void main() {
  group('SaimoTvParser', () {
    test('lê fontes nomeadas com referer e agente por servidor', () {
      const content = '''
canal: Globo
categoria: Aberto
logo: http://logo/globo.png
fonte: http://a/stream
nome: Principal
referer: http://referer
agente: Agente-A
fonte: http://b/stream
nome: Backup
agente: Agente-B
''';

      final items = SaimoTvParser.parse(content, sourceId: 'src');

      expect(items, hasLength(1));
      final item = items.single;
      expect(item.title, 'Globo');
      expect(item.displayGroup, 'Aberto');
      expect(item.streamUrl, 'http://a/stream');

      final servers = item.streamServers;
      expect(servers, hasLength(2));
      expect(servers.first.label, 'Principal');
      expect(servers.first.headers?['Referer'], 'http://referer');
      expect(servers.first.headers?['User-Agent'], 'Agente-A');
      expect(servers.last.label, 'Backup');
      expect(servers.last.headers?['User-Agent'], 'Agente-B');
    });

    test('fonte sem nome usa rótulo padrão', () {
      const content = '''
canal: Canal Simples
fonte: http://a/stream
''';

      final item = SaimoTvParser.parse(content, sourceId: 'src').single;

      expect(item.streamServers.single.label, 'Servidor');
    });
  });

  group('SaimoVodParser', () {
    test('separa servidores dublado e legendado de filmes', () {
      const content = 'Filme Teste (2024)\thttps://a/filme\tdub=https://b/dublado\tleg=https://c/legendado';

      final item = SaimoVodParser.parseFilmesFile(content, sourceId: 'src').single;
      final servers = item.streamServers;

      expect(servers, hasLength(3));
      expect(servers[0].label, 'Servidor');
      expect(servers[1].label, 'Dub');
      expect(servers[2].label, 'Leg');
      expect(servers[1].url, 'https://b/dublado');
      expect(servers[2].url, 'https://c/legendado');
    });

    test('separa servidores de episódios rotulados por áudio', () {
      const content = '''
@Serie Teste
1\t1\tdub\thttps://a/ep1
1\t2\tleg\thttps://b/ep2
''';

      final items = SaimoVodParser.parseSeriesLinks(
        content,
        sourceId: 'src',
        defaultGroup: 'Séries',
      );

      expect(items, hasLength(2));
      expect(items.first.seriesTitle, 'Serie Teste');
      expect(items.first.streamServers.single.label, 'Dub');
      expect(items.last.streamServers.single.label, 'Leg');
    });

    test('usa capas de fichas mesmo com espaços e acentos diferentes', () {
      const fichas = '''
capa: https://image.tmdb.org/t/p/w342
f\tA Teia\t1\t/teia.jpg\tSuspense
f\tA 13ª Emenda\t3\t/emenda.jpg\tDrama
s\tAção Total\t2\t/acao.jpg\tAção
''';
      final posters = SaimoVodParser.parsePostersFromFichas(fichas);

      final filme = SaimoVodParser.parseFilmesFile(
        'A  Teia\tdub=https://a/filme',
        sourceId: 'src',
        postersByTitle: posters,
      ).single;
      final filmeComSimbolo = SaimoVodParser.parseFilmesFile(
        'A 13o Emenda (2016)\tdub=https://a/emenda',
        sourceId: 'src',
        postersByTitle: posters,
      ).single;
      final serie = SaimoVodParser.parseSeriesFile(
        '@Acao Total\n1\t1\tdub\thttps://a/ep1',
        sourceId: 'src',
        postersByTitle: posters,
      ).single;

      expect(filme.logo, 'https://image.tmdb.org/t/p/w342/teia.jpg');
      expect(filmeComSimbolo.logo, 'https://image.tmdb.org/t/p/w342/emenda.jpg');
      expect(serie.logo, 'https://image.tmdb.org/t/p/w342/acao.jpg');
    });
  });
}
