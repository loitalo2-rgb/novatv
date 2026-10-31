import 'package:flutter_test/flutter_test.dart';
import 'package:novatv/data/models/playlist_source.dart';
import 'package:novatv/data/repositories/library_repository.dart';
import 'package:novatv/data/services/cache_store.dart';
import 'package:novatv/data/services/local_playlist_store.dart';
import 'package:novatv/data/services/preferences_service.dart';
import 'package:novatv/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _m3u = '''#EXTM3U
#EXTINF:-1 group-title="Ao Vivo",Canal Um
http://example.com/um.m3u8
#EXTINF:-1 group-title="Filmes",Filme Um
http://example.com/um.mp4
''';

const _seriesM3u = '''#EXTM3U
#EXTINF:-1 group-title="Séries",Serie Teste T1 E1
http://example.com/serie/s1e1.mp4
#EXTINF:-1 group-title="Séries",Serie Teste T1 E2
http://example.com/serie/s1e2.mp4
''';

class _MemoryCacheStore implements LibraryCacheStore {
  String? _cache;
  @override
  Future<void> clear() async => _cache = null;
  @override
  Future<String?> read() async => _cache;
  @override
  Future<void> write(String value) async => _cache = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('repositório usa o conteúdo da lista importada', () async {
    const source = PlaylistSource(id: 'src-1', name: 'Local', url: 'local://src-1');
    final result = await LibraryRepository().loadSource(source, localContent: _m3u);

    expect(result.ok, isTrue);
    expect(result.items, hasLength(2));
  });

  test('estado salva e recarrega uma lista importada de arquivo', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PreferencesService.create();
    final cache = _MemoryCacheStore();
    final state = AppState(preferences: prefs, cacheStore: cache);
    await state.init();

    // Remove a fonte padrão (Saimo TV) para testar apenas a lista importada
    for (final s in List.of(state.sources)) {
      await state.deleteSource(s.id);
    }

    await state.addSource(
      name: 'Minha lista',
      url: '',
      localContent: _m3u,
      localFileName: 'minha-lista.m3u',
    );

    expect(state.items, hasLength(2));
    final source = state.sources.single;
    expect(LocalPlaylistStore.isLocalUrl(source.url), isTrue);
    expect(state.localFileName(source.id), 'minha-lista.m3u');

    // Conteúdo persiste no aparelho mesmo depois de recriar o estado.
    final restored = AppState(preferences: prefs, cacheStore: cache);
    await restored.init();
    expect(restored.sources.single.url, source.url);
    expect(restored.localFileName(source.id), 'minha-lista.m3u');
    await restored.refresh();
    expect(restored.items, hasLength(2));
  });
}
