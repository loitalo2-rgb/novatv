import 'preferences_service.dart';

/// Guarda no aparelho o conteúdo das listas importadas de arquivos locais.
///
/// O `PlaylistSource.url` de uma lista importada fica como `local://<id>`; o
/// conteúdo real (texto M3U) é persistido aqui, junto com o nome do arquivo.
class LocalPlaylistStore {
  LocalPlaylistStore(this._prefs);

  final PreferencesService _prefs;

  static const String urlScheme = 'local://';

  static bool isLocalUrl(String url) => url.startsWith(urlScheme);

  static String localUrl(String sourceId) => '$urlScheme$sourceId';

  String? content(String sourceId) => _prefs.getString('localContent:$sourceId');

  String? fileName(String sourceId) => _prefs.getString('localFileName:$sourceId');

  Future<void> save(
    String sourceId, {
    required String content,
    required String fileName,
  }) async {
    await _prefs.setString('localContent:$sourceId', content);
    await _prefs.setString('localFileName:$sourceId', fileName);
  }

  Future<void> remove(String sourceId) async {
    await _prefs.remove('localContent:$sourceId');
    await _prefs.remove('localFileName:$sourceId');
  }
}
