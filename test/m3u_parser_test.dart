import 'package:flutter_test/flutter_test.dart';
import 'package:novatv/data/demo_content.dart';
import 'package:novatv/data/models/media_item.dart';
import 'package:novatv/data/parsers/m3u_parser.dart';

void main() {
  group('M3uParser', () {
    test('separa canal ao vivo, filmes e séries da lista de demonstração', () {
      final result = M3uParser.parse(demoPlaylistContent, sourceId: 'demo');

      final live = result.items.where((item) => item.kind == MediaKind.live).toList();
      final movies = result.items.where((item) => item.kind == MediaKind.movie).toList();
      final series = result.items.where((item) => item.kind == MediaKind.series).toList();

      expect(live, hasLength(1));
      expect(live.single.title, 'Canal Demo');
      expect(movies, hasLength(4));
      expect(series, hasLength(3));
      expect(series.first.seriesTitle, 'Série Demo');
      expect(series.first.season, 1);
      expect(series.first.episode, 1);
    });

    test('lê atributos e ignora entradas repetidas', () {
      const content = '''#EXTM3U
#EXTINF:-1 tvg-id="c1" tvg-logo="http://x/logo.png" group-title="Canais | Notícias",Canal Um
http://example.com/um.m3u8
#EXTINF:-1 group-title="Filmes",Filme Legal
http://example.com/filme.mp4
#EXTINF:-1 group-title="Filmes",Filme Legal
http://example.com/filme.mp4
''';
      final result = M3uParser.parse(content, sourceId: 's1');

      expect(result.items, hasLength(2));
      expect(result.skipped, 1);
      expect(result.items.first.tvgId, 'c1');
      expect(result.items.first.logo, 'http://x/logo.png');
      expect(result.items.first.kind, MediaKind.live);
      expect(result.items.last.kind, MediaKind.movie);
    });
  });
}
