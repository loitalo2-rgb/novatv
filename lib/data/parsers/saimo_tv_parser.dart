import '../models/media_item.dart';

class _ChannelSource {
  _ChannelSource({required this.url, Map<String, String>? headers})
      : headers = headers ?? <String, String>{};

  final String url;
  String? name;
  final Map<String, String> headers;
}

class SaimoTvParser {
  static List<MediaItem> parse(String content, {required String sourceId, bool isRestricted = false}) {
    final List<MediaItem> items = [];
    final lines = content.split('\n');

    String? currentCanal;
    String? currentCategoria;
    String? currentLogo;
    final List<_ChannelSource> currentFontes = [];
    _ChannelSource? currentFonte;

    void addItem() {
      final canal = currentCanal;
      if (canal != null && currentFontes.isNotEmpty) {
        final primary = currentFontes.first;
        final servers = currentFontes
            .map((source) => StreamServer(
                  url: source.url,
                  name: source.name,
                  headers: source.headers.isEmpty ? null : Map<String, String>.from(source.headers),
                ))
            .toList();

        items.add(MediaItem(
          id: '$sourceId-${canal.replaceAll(' ', '_')}',
          title: canal,
          streamUrl: primary.url,
          kind: MediaKind.live,
          sourceId: sourceId,
          group: (isRestricted ? 'Restritos | ' : '') + (currentCategoria ?? 'Canais'),
          logo: currentLogo,
          tvgId: canal,
          headers: primary.headers.isNotEmpty ? Map<String, String>.from(primary.headers) : null,
          alternateStreams: servers.length > 1 ? servers.skip(1).map((server) => server.url).toList() : null,
          servers: servers,
        ));
      }
      currentFontes.clear();
      currentFonte = null;
    }

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('canal:')) {
        if (currentCanal != null) addItem();
        currentCanal = line.substring(6).trim();
        currentCategoria = null;
        currentLogo = null;
      } else if (line.startsWith('categoria:')) {
        currentCategoria = line.substring(10).trim();
      } else if (line.startsWith('logo:')) {
        currentLogo = line.substring(5).trim();
      } else if (line.startsWith('fonte:')) {
        final url = line.substring(6).trim();
        final fonte = _ChannelSource(url: url);
        currentFonte = fonte;
        currentFontes.add(fonte);
      } else if (line.startsWith('nome:') && currentFonte != null) {
        currentFonte!.name = line.substring(5).trim();
      } else if (line.startsWith('referer:') && currentFonte != null) {
        currentFonte!.headers['Referer'] = line.substring(8).trim();
      } else if (line.startsWith('agente:') && currentFonte != null) {
        currentFonte!.headers['User-Agent'] = line.substring(7).trim();
      }
    }

    if (currentCanal != null) addItem();

    return items;
  }
}
