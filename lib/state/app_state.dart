import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/utils.dart';
import '../data/demo_content.dart';
import '../data/models/epg_program.dart';
import '../data/models/media_item.dart';
import '../data/models/playlist_source.dart';
import '../data/models/watch_progress.dart';
import '../data/repositories/library_repository.dart';
import '../data/services/cache_store.dart';
import '../data/services/local_playlist_store.dart';
import '../data/services/preferences_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    PreferencesService? preferences,
    LibraryRepository? repository,
    LibraryCacheStore? cacheStore,
  })  : _prefs = preferences,
        _repository = repository ?? LibraryRepository(),
        _cache = cacheStore ?? createLibraryCacheStore();

  PreferencesService? _prefs;
  LocalPlaylistStore? _local;
  final LibraryRepository _repository;
  final LibraryCacheStore _cache;

  final List<PlaylistSource> _sources = [];
  List<MediaItem> _items = const [];
  List<SeriesGroup> _seriesGroups = const [];
  EpgGuide _epg = EpgGuide.empty;
  final Set<String> _favorites = <String>{};
  final Map<String, WatchProgress> _progress = <String, WatchProgress>{};

  bool _initialized = false;
  bool _loading = false;
  bool _refreshing = false;
  String? _error;
  DateTime? _lastRefresh;
  int _autoRefreshMinutes = 60;
  String? _tmdbKey;
  Timer? _timer;
  int _sourcesRevision = 0;

  bool get initialized => _initialized;
  bool get loading => _loading;
  String? get error => _error;
  DateTime? get lastRefresh => _lastRefresh;
  int get autoRefreshMinutes => _autoRefreshMinutes;
  String? get tmdbKey => _tmdbKey;
  List<PlaylistSource> get sources => List.unmodifiable(_sources);
  List<MediaItem> get items => _items;
  List<SeriesGroup> get seriesGroups => _seriesGroups;
  EpgGuide get epg => _epg;
  bool get hasSources => _sources.any((s) => s.enabled);
  bool get isEmpty => _items.isEmpty;
  bool get isStale {
    if (_lastRefresh == null) return true;
    if (_autoRefreshMinutes <= 0) return false;
    final minutes = DateTime.now().difference(_lastRefresh!).inMinutes;
    return minutes >= _autoRefreshMinutes;
  }

  Future<void> init() async {
    if (_initialized) return;
    _prefs ??= await PreferencesService.create();
    _local ??= LocalPlaylistStore(_prefs!);
    _loadSources();

    // A cópia pública começa com conteúdo de demonstração e sem listas externas.
    if (_sources.isEmpty) {
      _sources.add(const PlaylistSource(
        id: 'demo',
        name: 'Demonstração',
        url: demoPlaylistUrl,
      ));
      await _saveSources();
    }

    _loadFavorites();
    _loadProgress();
    _autoRefreshMinutes = _prefs!.getInt('autoRefreshMinutes', fallback: 60);
    _tmdbKey = _prefs!.getString('tmdbKey');
    await _loadCache();
    _rebuildDerived();
    _initialized = true;
    notifyListeners();
    _scheduleAutoRefresh();
    if (hasSources && (isEmpty || isStale)) {
      unawaited(refresh());
    }
  }

  // ---------------------------------------------------------------------------
  // Fontes / listas
  // ---------------------------------------------------------------------------

  Future<void> addSource({
    required String name,
    required String url,
    String? epgUrl,
    String? localContent,
    String? localFileName,
  }) async {
    final id = 'src-${DateTime.now().microsecondsSinceEpoch}';
    final source = PlaylistSource(
      id: id,
      name: name.trim().isEmpty ? 'Minha lista' : name.trim(),
      url: localContent != null ? LocalPlaylistStore.localUrl(id) : url.trim(),
      epgUrl: _emptyToNull(epgUrl),
    );
    if (localContent != null) {
      await _local!.save(
        id,
        content: localContent,
        fileName: localFileName ?? 'lista.m3u',
      );
    }
    _sources.add(source);
    _sourcesRevision++;
    await _saveSources();
    notifyListeners();
    await refreshSource(source.id);
  }

  String? localFileName(String sourceId) {
    for (final source in _sources) {
      if (source.id == sourceId && LocalPlaylistStore.isLocalUrl(source.url)) {
        return _local?.fileName(sourceId);
      }
    }
    return null;
  }

  /// Substitui o conteúdo de uma lista importada (renomear/trocar arquivo).
  Future<void> updateLocalSource(
    PlaylistSource source, {
    required String name,
    required String content,
    required String fileName,
    String? epgUrl,
  }) async {
    final index = _sources.indexWhere((s) => s.id == source.id);
    if (index < 0) return;
    await _local!.save(source.id, content: content, fileName: fileName);
    _sources[index] = PlaylistSource(
      id: source.id,
      name: name.trim().isEmpty ? source.name : name.trim(),
      url: LocalPlaylistStore.localUrl(source.id),
      epgUrl: _emptyToNull(epgUrl),
      enabled: source.enabled,
      lastUpdated: source.lastUpdated,
      itemCount: source.itemCount,
      refreshMinutes: source.refreshMinutes,
    );
    _sourcesRevision++;
    await _saveSources();
    notifyListeners();
    await refreshSource(source.id);
  }

  Future<void> addDemoSource() async {
    if (_sources.any((s) => s.url == demoPlaylistUrl)) return;
    final source = PlaylistSource(
      id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Demonstração',
      url: demoPlaylistUrl,
    );
    _sources.add(source);
    _sourcesRevision++;
    await _saveSources();
    notifyListeners();
    await refreshSource(source.id);
  }

  Future<void> updateSource(PlaylistSource updated) async {
    final index = _sources.indexWhere((s) => s.id == updated.id);
    if (index < 0) return;
    _sources[index] = updated;
    _sourcesRevision++;
    await _saveSources();
    notifyListeners();
  }

  Future<void> deleteSource(String id) async {
    _sources.removeWhere((s) => s.id == id);
    _sourcesRevision++;
    await _local?.remove(id);
    _items = _items.where((item) => item.sourceId != id).toList();
    _rebuildDerived();
    await _saveSources();
    await _saveCache();
    notifyListeners();
  }

  Future<void> setSourceEnabled(String id, bool enabled) async {
    final index = _sources.indexWhere((s) => s.id == id);
    if (index < 0) return;
    final source = _sources[index].copyWith(enabled: enabled);
    _sources[index] = source;
    _sourcesRevision++;
    await _saveSources();
    notifyListeners();
    if (enabled) {
      await refreshSource(id);
    } else {
      _items = _items.where((item) => item.sourceId != id).toList();
      _rebuildDerived();
      await _saveCache();
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_refreshing || _sources.isEmpty) return;
    _refreshing = true;
    _loading = true;
    _error = null;
    notifyListeners();

    final revision = _sourcesRevision;
    final previous = _items;
    final collected = <MediaItem>[];
    final errors = <String>[];
    final updated = <PlaylistSource>[];

    for (final source in List<PlaylistSource>.from(_sources)) {
      if (!source.enabled) {
        collected.addAll(previous.where((item) => item.sourceId == source.id));
        updated.add(source);
        continue;
      }
      final result = await _repository.loadSource(
        source,
        localContent: LocalPlaylistStore.isLocalUrl(source.url) ? _local?.content(source.id) : null,
      );
      if (result.ok) {
        collected.addAll(result.items);
        updated.add(source.copyWith(
          lastUpdated: DateTime.now(),
          itemCount: result.items.length,
          clearError: true,
        ));
      } else {
        collected.addAll(previous.where((item) => item.sourceId == source.id));
        updated.add(source.copyWith(lastError: result.error));
        errors.add('${source.name}: ${result.error}');
      }
    }

    if (revision != _sourcesRevision) {
      _loading = false;
      _refreshing = false;
      notifyListeners();
      return;
    }

    _sources
      ..clear()
      ..addAll(updated);
    _items = _dedupe(collected);
    _rebuildDerived();
    _lastRefresh = DateTime.now();
    _error = errors.isEmpty ? null : errors.join('\n');
    _loading = false;
    _refreshing = false;

    await _saveSources();
    await _saveCache();
    notifyListeners();
    unawaited(_refreshEpg());
  }

  Future<void> refreshSource(String id) async {
    final index = _sources.indexWhere((s) => s.id == id);
    if (index < 0) return;
    final source = _sources[index];
    final revision = _sourcesRevision;

    _loading = true;
    notifyListeners();

    final result = await _repository.loadSource(
      source,
      localContent: LocalPlaylistStore.isLocalUrl(source.url) ? _local?.content(id) : null,
    );
    if (revision != _sourcesRevision) {
      _loading = false;
      notifyListeners();
      return;
    }
    final others = _items.where((item) => item.sourceId != id);

    if (result.ok) {
      _items = _dedupe([...others, ...result.items]);
      _sources[index] = source.copyWith(
        lastUpdated: DateTime.now(),
        itemCount: result.items.length,
        clearError: true,
      );
      _error = null;
    } else {
      _sources[index] = source.copyWith(lastError: result.error);
      _error = '${source.name}: ${result.error}';
    }

    _lastRefresh = DateTime.now();
    _rebuildDerived();
    _loading = false;
    await _saveSources();
    await _saveCache();
    notifyListeners();
    unawaited(_refreshEpg());
  }

  // ---------------------------------------------------------------------------
  // EPG
  // ---------------------------------------------------------------------------

  Future<void> _refreshEpg() async {
    final withEpg = _sources.where((s) => s.enabled && (s.epgUrl?.isNotEmpty ?? false)).toList();
    if (withEpg.isEmpty) {
      if (!_epg.isEmpty) {
        _epg = EpgGuide.empty;
        notifyListeners();
      }
      return;
    }

    final merged = <String, List<EpgProgram>>{};
    final names = <String, String>{};

    for (final source in withEpg) {
      try {
        final guide = await _repository.loadEpg(source.epgUrl!);
        guide.channelNames.forEach((key, value) => names[key] = value);
        guide.byChannel.forEach((key, value) => merged.putIfAbsent(key, () => []).addAll(value));
      } catch (_) {
        // Guia é opcional: uma falha não interrompe a lista.
      }
    }

    for (final programs in merged.values) {
      programs.sort((a, b) => a.start.compareTo(b.start));
    }

    _epg = EpgGuide(byChannel: merged, channelNames: names);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Favoritos e progresso
  // ---------------------------------------------------------------------------

  bool isFavorite(String itemId) => _favorites.contains(itemId);

  List<MediaItem> get favorites {
    final result = _items.where((item) => _favorites.contains(item.id)).toList();
    final ids = result.map((item) => item.id).toSet();

    // Séries favoritadas usam a chave do grupo (id sintético), que pode não
    // existir em `_items`. Recria o item de catálogo a partir do grupo.
    for (final group in _seriesGroups) {
      if (_favorites.contains(group.key) && !ids.contains(group.key)) {
        result.add(seriesGroupAsItem(group));
        ids.add(group.key);
      }
    }
    return result;
  }

  Future<void> toggleFavorite(MediaItem item) async {
    if (!_favorites.remove(item.id)) {
      _favorites.add(item.id);
    }
    notifyListeners();
    await _prefs?.setString('favorites', jsonEncode(_favorites.toList()));
  }

  WatchProgress? progressFor(String itemId) => _progress[itemId];

  List<WatchProgress> get continueWatching {
    final list = _progress.values.where((p) => p.canResume).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.take(20).toList();
  }

  Future<void> saveProgress(MediaItem item, Duration position, Duration duration) async {
    if (item.kind == MediaKind.live) return;
    if (position.inSeconds < 10) return;

    if (duration.inSeconds > 0 && position.inSeconds >= duration.inSeconds - 25) {
      await clearProgress(item.id);
      return;
    }

    _progress[item.id] = WatchProgress(
      itemId: item.id,
      title: item.title,
      streamUrl: item.streamUrl,
      kindName: item.kind.name,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
      updatedAt: DateTime.now(),
      logo: item.logo,
      group: item.group,
      seriesTitle: item.seriesTitle,
      season: item.season,
      episode: item.episode,
    );

    if (_progress.length > 200) {
      final ordered = _progress.values.toList()..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      for (final old in ordered.take(_progress.length - 200)) {
        _progress.remove(old.itemId);
      }
    }

    await _persistProgress();
    notifyListeners();
  }

  Future<void> clearProgress(String itemId) async {
    if (_progress.remove(itemId) == null) return;
    await _persistProgress();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Busca e agrupamentos
  // ---------------------------------------------------------------------------

  List<MediaItem> get liveItems => _items.where((i) => i.kind == MediaKind.live).toList();
  List<MediaItem> get movieItems => _items.where((i) => i.kind == MediaKind.movie).toList();
  List<MediaItem> get seriesEpisodes => _items.where((i) => i.kind == MediaKind.series).toList();

  List<String> get liveCategories => _categoriesOf(liveItems);
  List<String> get movieCategories => _categoriesOf(movieItems);

  List<MediaItem> search(String query) {
    final q = normalizeText(query);
    if (q.isEmpty) return const [];
    return _items
        .where((item) =>
            normalizeText(item.title).contains(q) ||
            normalizeText(item.group ?? '').contains(q) ||
            (item.seriesTitle != null && normalizeText(item.seriesTitle!).contains(q)))
        .take(300)
        .toList();
  }

  SeriesGroup? seriesGroupByKey(String key) {
    for (final group in _seriesGroups) {
      if (group.key == key) return group;
    }
    return null;
  }

  List<String> _categoriesOf(List<MediaItem> list) {
    final counts = <String, int>{};
    for (final item in list) {
      counts[item.displayGroup] = (counts[item.displayGroup] ?? 0) + 1;
    }
    final names = counts.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  // ---------------------------------------------------------------------------
  // Ajustes
  // ---------------------------------------------------------------------------

  Future<void> setAutoRefreshMinutes(int minutes) async {
    _autoRefreshMinutes = minutes;
    await _prefs?.setInt('autoRefreshMinutes', minutes);
    _scheduleAutoRefresh();
    notifyListeners();
  }

  Future<void> setTmdbKey(String? key) async {
    final value = _emptyToNull(key);
    _tmdbKey = value;
    if (value == null) {
      await _prefs?.remove('tmdbKey');
    } else {
      await _prefs?.setString('tmdbKey', value);
    }
    notifyListeners();
  }

  Future<void> clearProgressHistory() async {
    _progress.clear();
    await _persistProgress();
    notifyListeners();
  }

  Future<void> clearFavorites() async {
    _favorites.clear();
    await _prefs?.setString('favorites', '[]');
    notifyListeners();
  }

  void _scheduleAutoRefresh() {
    _timer?.cancel();
    if (_autoRefreshMinutes <= 0) return;
    _timer = Timer.periodic(Duration(minutes: _autoRefreshMinutes), (_) {
      if (!_refreshing) unawaited(refresh());
    });
  }

  // ---------------------------------------------------------------------------
  // Persistência
  // ---------------------------------------------------------------------------

  void _loadSources() {
    final raw = _prefs?.getString('sources');
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      _sources
        ..clear()
        ..addAll(data.map((e) => PlaylistSource.fromJson(e as Map<String, dynamic>)));
    } catch (_) {}
  }

  void _loadFavorites() {
    final raw = _prefs?.getString('favorites');
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      _favorites
        ..clear()
        ..addAll(data.cast<String>());
    } catch (_) {}
  }

  void _loadProgress() {
    final raw = _prefs?.getString('progress');
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      _progress.clear();
      for (final entry in data) {
        final progress = WatchProgress.fromJson(entry as Map<String, dynamic>);
        _progress[progress.itemId] = progress;
      }
    } catch (_) {}
  }

  Future<void> _saveSources() async {
    await _prefs?.setString('sources', jsonEncode(_sources.map((s) => s.toJson()).toList()));
  }

  Future<void> _persistProgress() async {
    await _prefs?.setString('progress', jsonEncode(_progress.values.map((p) => p.toJson()).toList()));
  }

  Future<void> _saveCache() async {
    try {
      final payload = jsonEncode({
        'version': 2,
        'savedAt': DateTime.now().toIso8601String(),
        'items': _items.map((item) => item.toJson()).toList(),
      });
      await _cache.write(payload);
    } catch (_) {}
  }

  Future<void> _loadCache() async {
    if (_items.isNotEmpty) return;
    try {
      final raw = await _cache.read();
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      // Versão antiga não tinha capas; descarta para forçar nova atualização.
      if (data['version'] != 2) return;
      final list = (data['items'] as List<dynamic>?) ?? const [];
      _items = list.map((e) => MediaItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Auxiliares
  // ---------------------------------------------------------------------------

  void _rebuildDerived() {
    final map = <String, List<MediaItem>>{};
    for (final item in _items.where((i) => i.kind == MediaKind.series)) {
      map.putIfAbsent(item.seriesKey, () => []).add(item);
    }

    final groups = <SeriesGroup>[];
    for (final entry in map.entries) {
      final episodes = entry.value..sort(_compareEpisodes);
      String? logo;
      for (final episode in episodes) {
        if (episode.logo != null && episode.logo!.isNotEmpty) {
          logo = episode.logo;
          break;
        }
      }
      groups.add(SeriesGroup(
        key: entry.key,
        title: episodes.first.seriesTitle ?? episodes.first.title,
        group: episodes.first.displayGroup,
        episodes: episodes,
        logo: logo,
      ));
    }

    groups.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _seriesGroups = groups;
  }

  static int _compareEpisodes(MediaItem a, MediaItem b) {
    final season = (a.season ?? 0).compareTo(b.season ?? 0);
    if (season != 0) return season;
    return (a.episode ?? 0).compareTo(b.episode ?? 0);
  }

  static List<MediaItem> _dedupe(List<MediaItem> input) {
    final seen = <String>{};
    final result = <MediaItem>[];
    for (final item in input) {
      if (seen.add(item.id)) result.add(item);
    }
    return result;
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
