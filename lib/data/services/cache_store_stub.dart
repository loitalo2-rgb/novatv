import 'cache_store.dart';

LibraryCacheStore buildLibraryCacheStore() => _NoopCacheStore();

class _NoopCacheStore implements LibraryCacheStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}

  @override
  Future<void> clear() async {}
}
