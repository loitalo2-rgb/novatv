import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/media_item.dart';
import '../../data/models/watch_progress.dart';
import '../../state/app_state.dart';
import '../navigation.dart';

class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({super.key, required this.group});

  final SeriesGroup group;

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  List<String> _serverLabels = const [];
  String? _selectedServerLabel;

  @override
  void initState() {
    super.initState();
    _serverLabels = _collectServerLabels();
    _selectedServerLabel = _serverLabels.isEmpty ? null : _serverLabels.first;
  }

  List<String> _collectServerLabels() {
    final labels = <String>{};
    for (final episode in widget.group.episodes) {
      final servers = episode.streamServers;
      for (var index = 0; index < servers.length; index++) {
        labels.add(streamServerOptionLabel(servers[index], index));
      }
    }
    return labels.toList();
  }

  int _serverIndexFor(MediaItem episode) {
    final servers = episode.streamServers;
    if (servers.isEmpty) return 0;
    final selected = _selectedServerLabel;
    if (selected != null) {
      for (var index = 0; index < servers.length; index++) {
        final label = streamServerOptionLabel(servers[index], index);
        if (label == selected) return index;
      }
    }
    return 0;
  }

  void _openEpisode(BuildContext context, MediaItem episode, WatchProgress? progress) {
    final startAt = progress != null && progress.canResume ? progress.position : null;
    openMedia(
      context,
      episode,
      startAt: startAt,
      initialStreamIndex: _serverIndexFor(episode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final state = context.watch<AppState>();
    final seasons = <int, List<MediaItem>>{};
    for (final episode in group.episodes) {
      seasons.putIfAbsent(episode.season ?? 1, () => []).add(episode);
    }
    final seasonKeys = seasons.keys.toList()..sort();

    final first = group.episodes.first;
    final firstProgress = state.progressFor(first.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (group.posterUrl.isNotEmpty)
                    Image.network(
                      group.posterUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _SeriesHeroFallback(),
                    )
                  else
                    const _SeriesHeroFallback(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.background],
                        stops: [0.35, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.title,
                    style: const TextStyle(fontSize: 34, height: 1.1, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${group.group} · ${countLabel(group.episodes.length, 'episódio', 'episódios')} · '
                    '${countLabel(seasonKeys.length, 'temporada', 'temporadas')}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                  if (first.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 780),
                      child: Text(
                        first.description!,
                        style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFC9CBD6)),
                      ),
                    ),
                  ],
                  if (_serverLabels.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.language_rounded, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          _serverLabels.length > 1 ? 'Idioma / servidor' : 'Idioma',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final label in _serverLabels)
                          if (_serverLabels.length > 1)
                            ChoiceChip(
                              label: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight:
                                      _selectedServerLabel == label ? FontWeight.w800 : FontWeight.w500,
                                  color: _selectedServerLabel == label ? Colors.black : AppColors.text,
                                ),
                              ),
                              selected: _selectedServerLabel == label,
                              showCheckmark: false,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => setState(() => _selectedServerLabel = label),
                            )
                          else
                            Chip(
                              label: Text(label, style: const TextStyle(fontSize: 11.5)),
                              visualDensity: VisualDensity.compact,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openEpisode(context, first, firstProgress),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(firstProgress != null && firstProgress.canResume ? 'Continuar' : 'Assistir T1 E1'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.read<AppState>().toggleFavorite(seriesGroupAsItem(group)),
                        icon: Icon(
                          state.isFavorite(group.key)
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 19,
                        ),
                        label: Text(
                          state.isFavorite(group.key) ? 'Na minha lista' : 'Minha lista',
                        ),
                      ),
                      if (firstProgress != null && firstProgress.canResume)
                        Text(
                          firstProgress.resumeLabel,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          for (final season in seasonKeys) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 10),
                child: Row(
                  children: [
                    Text(
                      'Temporada $season',
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${seasons[season]!.length} episódios',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            SliverList.builder(
              itemCount: seasons[season]!.length,
              itemBuilder: (context, index) {
                final episode = seasons[season]![index];
                final progress = state.progressFor(episode.id);
                return _EpisodeTile(
                  episode: episode,
                  progress: progress,
                  onTap: () => _openEpisode(context, episode, progress),
                );
              },
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.episode, required this.onTap, this.progress});

  final MediaItem episode;
  final VoidCallback onTap;
  final WatchProgress? progress;

  @override
  Widget build(BuildContext context) {
    final hasProgress = progress != null && progress!.canResume;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${episode.episode ?? '-'}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.accent),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.episodeLabel.isEmpty ? episode.title : '${episode.episodeLabel} · ${episode.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasProgress ? 'Continuar de ${formatDuration(progress!.position)}' : 'Assistir',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                      ),
                      if (hasProgress) ...[
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress!.fraction,
                            minHeight: 3,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.play_circle_outline_rounded, color: AppColors.text, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeriesHeroFallback extends StatelessWidget {
  const _SeriesHeroFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2E6B), AppColors.background, Color(0xFF0B4E3D)],
        ),
      ),
    );
  }
}

