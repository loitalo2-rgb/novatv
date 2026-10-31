import 'cache_store_stub.dart'
    if (dart.library.io) 'cache_store_io.dart'
    if (dart.library.js_interop) 'cache_store_web.dart';

abstract class LibraryCacheStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

LibraryCacheStore createLibraryCacheStore() => buildLibraryCacheStore();
