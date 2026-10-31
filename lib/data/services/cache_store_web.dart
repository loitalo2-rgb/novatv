import 'package:shared_preferences/shared_preferences.dart';

import 'cache_store.dart';

LibraryCacheStore buildLibraryCacheStore() => _WebCacheStore();

class _WebCacheStore implements LibraryCacheStore {
  static const _key = 'novatv_library_cache';
  static const _limit = 3500000;

  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> write(String value) async {
    if (value.length > _limit) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
