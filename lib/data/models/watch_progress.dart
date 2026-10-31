import '../../core/utils.dart';
import 'media_item.dart';

class WatchProgress {
  const WatchProgress({
    required this.itemId,
    required this.title,
    required this.streamUrl,
    required this.kindName,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
    this.logo,
    this.group,
    this.seriesTitle,
    this.season,
    this.episode,
  });

  final String itemId;
  final String title;
  final String streamUrl;
  final String kindName;
  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;
  final String? logo;
  final String? group;
  final String? seriesTitle;
  final int? season;
  final int? episode;

  Duration get position => Duration(milliseconds: positionMs);
  Duration get duration => Duration(milliseconds: durationMs);
  bool get canResume => positionMs > 15000 && (durationMs == 0 || positionMs < durationMs * 0.95);
  double get fraction => durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0.0, 1.0);
  String get kindLabel => kindName == 'movie' ? 'Filme' : (kindName == 'series' ? 'Série' : 'Ao vivo');

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'title': title,
        'streamUrl': streamUrl,
        'kindName': kindName,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'updatedAt': updatedAt.toIso8601String(),
        'logo': logo,
        'group': group,
        'seriesTitle': seriesTitle,
        'season': season,
        'episode': episode,
      };

  factory WatchProgress.fromJson(Map<String, dynamic> json) {
    return WatchProgress(
      itemId: json['itemId'] as String,
      title: (json['title'] as String?) ?? '',
      streamUrl: (json['streamUrl'] as String?) ?? '',
      kindName: (json['kindName'] as String?) ?? 'movie',
      positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ?? DateTime.now(),
      logo: json['logo'] as String?,
      group: json['group'] as String?,
      seriesTitle: json['seriesTitle'] as String?,
      season: json['season'] as int?,
      episode: json['episode'] as int?,
    );
  }

  String get subtitle {
    if (seriesTitle != null) {
      final parts = <String>['$seriesTitle'];
      if (season != null) parts.add('T${season!.toString().padLeft(2, '0')}');
      if (episode != null) parts.add('E${episode!.toString().padLeft(2, '0')}');
      return parts.join(' · ');
    }
    return group ?? kindLabel;
  }

  static String subtitleFor({String? seriesTitle, int? season, int? episode, String? group}) {
    if (seriesTitle != null && seriesTitle.isNotEmpty) {
      final parts = <String>[seriesTitle];
      if (season != null) parts.add('T${season.toString().padLeft(2, '0')}');
      if (episode != null) parts.add('E${episode.toString().padLeft(2, '0')}');
      return parts.join(' · ');
    }
    return group ?? '';
  }

  String get resumeLabel => '${formatDuration(position)} de ${formatDuration(duration)}';

  MediaItem toMediaItem() {
    return MediaItem(
      id: itemId,
      title: title,
      streamUrl: streamUrl,
      kind: mediaKindFromName(kindName),
      sourceId: '',
      logo: logo,
      group: group,
      seriesTitle: seriesTitle,
      season: season,
      episode: episode,
    );
  }
}
