import 'package:flutter_test/flutter_test.dart';
import 'package:novatv/data/models/media_item.dart';

void main() {
  group('MediaItem.streamServers', () {
    test('monta servidores a partir do link principal e alternativos', () {
      const item = MediaItem(
        id: '1',
        title: 'Canal',
        streamUrl: 'http://a/stream',
        kind: MediaKind.live,
        sourceId: 's',
        alternateStreams: ['http://b/stream', 'http://a/stream'],
      );

      final servers = item.streamServers;

      expect(servers, hasLength(2));
      expect(servers.first.url, 'http://a/stream');
      expect(servers.last.url, 'http://b/stream');
    });

    test('usa nomes e cabeçalhos declarados por servidor', () {
      const item = MediaItem(
        id: '2',
        title: 'Canal',
        streamUrl: 'http://a/stream',
        kind: MediaKind.live,
        sourceId: 's',
        servers: [
          StreamServer(url: 'http://a/stream', name: 'Principal'),
          StreamServer(
            url: 'http://b/stream',
            name: 'Backup',
            headers: {'Referer': 'http://exemplo'},
          ),
        ],
      );

      final servers = item.streamServers;

      expect(servers, hasLength(2));
      expect(servers.first.label, 'Principal');
      expect(servers.last.label, 'Backup');
      expect(servers.last.headers?['Referer'], 'http://exemplo');
    });
  });
}
