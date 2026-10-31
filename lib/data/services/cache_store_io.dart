import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'cache_store.dart';

LibraryCacheStore buildLibraryCacheStore() => _IoCacheStore();

class _IoCacheStore implements LibraryCacheStore {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}library_cache.json');
  }

  @override
  Future<String?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String value) async {
    try {
      final file = await _file();
      await file.writeAsString(value, flush: true);
    } catch (_) {
      // Cache é opcional: falhar aqui não deve quebrar o app.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
