class PlaylistSource {
  const PlaylistSource({
    required this.id,
    required this.name,
    required this.url,
    this.epgUrl,
    this.enabled = true,
    this.lastUpdated,
    this.itemCount,
    this.lastError,
    this.refreshMinutes = 60,
  });

  final String id;
  final String name;
  final String url;
  final String? epgUrl;
  final bool enabled;
  final DateTime? lastUpdated;
  final int? itemCount;
  final String? lastError;
  final int refreshMinutes;

  PlaylistSource copyWith({
    String? name,
    String? url,
    String? epgUrl,
    bool? enabled,
    DateTime? lastUpdated,
    int? itemCount,
    String? lastError,
    bool clearError = false,
    int? refreshMinutes,
  }) {
    return PlaylistSource(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      epgUrl: epgUrl ?? this.epgUrl,
      enabled: enabled ?? this.enabled,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      itemCount: itemCount ?? this.itemCount,
      lastError: clearError ? null : (lastError ?? this.lastError),
      refreshMinutes: refreshMinutes ?? this.refreshMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'epgUrl': epgUrl,
        'enabled': enabled,
        'lastUpdated': lastUpdated?.toIso8601String(),
        'itemCount': itemCount,
        'lastError': lastError,
        'refreshMinutes': refreshMinutes,
      };

  factory PlaylistSource.fromJson(Map<String, dynamic> json) {
    return PlaylistSource(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Lista',
      url: json['url'] as String,
      epgUrl: json['epgUrl'] as String?,
      enabled: (json['enabled'] as bool?) ?? true,
      lastUpdated: json['lastUpdated'] != null ? DateTime.tryParse(json['lastUpdated'] as String) : null,
      itemCount: json['itemCount'] as int?,
      lastError: json['lastError'] as String?,
      refreshMinutes: (json['refreshMinutes'] as int?) ?? 60,
    );
  }
}
