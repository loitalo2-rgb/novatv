import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/media_item.dart';
import '../../state/app_state.dart';
import '../app_tabs.dart';
import '../flows.dart';
import '../navigation.dart';
import '../widgets/app_logo.dart';
import '../widgets/empty_state.dart';
import '../widgets/hero_banner.dart';
import '../widgets/media_card.dart';
import '../widgets/media_row.dart';
import 'series_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<AppTab> onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.hasSources && state.items.isEmpty) {
      return _Onboarding(
        loading: state.loading,
        onAdd: () => addOrEditSourceFlow(context),
        onDemo: () => addDemoFlow(context),
      );
    }

    if (state.items.isEmpty) {
      if (state.loading) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 18),
              Text('Carregando sua programação…', style: TextStyle(color: AppColors.textMuted)),
            ],
          ),
        );
      }
      return EmptyState(
        icon: Icons.playlist_remove_rounded,
        title: 'Sua lista voltou vazia',
        message: 'Confira o link da lista em Ajustes ou adicione outra fonte.',
        action: FilledButton.icon(
          onPressed: () => onNavigate(AppTab.settings),
          icon: const Icon(Icons.settings_rounded),
          label: const Text('Abrir ajustes'),
        ),
      );
    }

    final featured = _featured(state);
    final live = state.liveItems;
    final movies = state.movieItems;
    final series = state.seriesGroups;
    final favorites = state.favorites;
    final continueWatching = state.continueWatching;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: const SizedBox(height: 6)),
        if (featured != null)
          SliverToBoxAdapter(
            child: HeroBanner(
              item: featured,
              isFavorite: state.isFavorite(featured.id),
              onPlay: () => openMediaWithServerChoice(context, featured),
              onToggleFavorite: () => context.read<AppState>().toggleFavorite(featured),
              onDetails: () => showItemDetails(context, featured),
            ),
          ),
        if (state.error != null)
          SliverToBoxAdapter(child: ErrorBanner(message: state.error!)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (continueWatching.isNotEmpty)
                  MediaRow(
                    title: 'Continuar assistindo',
                    height: 154,
                    children: [
                      for (final progress in continueWatching)
                        ContinueCard(
                          progress: progress,
                          onTap: () => openMedia(
                            context,
                            progress.toMediaItem(),
                            startAt: progress.position,
                          ),
                        ),
                    ],
                  ),
                if (live.isNotEmpty)
                  MediaRow(
                    title: 'Ao vivo agora',
                    height: 132,
                    onSeeAll: () => onNavigate(AppTab.live),
                    children: [
                      for (final item in live.take(14))
                        MediaCard(
                          item: item,
                          isFavorite: state.isFavorite(item.id),
                          onToggleFavorite: () => context.read<AppState>().toggleFavorite(item),
                          onTap: () => openMedia(context, item),
                        ),
                    ],
                  ),
                if (movies.isNotEmpty)
                  MediaRow(
                    title: 'Filmes',
                    height: 240,
                    onSeeAll: () => onNavigate(AppTab.catalog),
                    children: [
                      for (final item in movies.take(20))
                        MediaCard(
                          item: item,
                          width: 156,
                          isFavorite: state.isFavorite(item.id),
                          onToggleFavorite: () => context.read<AppState>().toggleFavorite(item),
                          onTap: () => openMediaWithServerChoice(context, item),
                        ),
                    ],
                  ),
                if (series.isNotEmpty)
                  MediaRow(
                    title: 'Séries',
                    height: 240,
                    onSeeAll: () => onNavigate(AppTab.catalog),
                    children: [
                      for (final group in series.take(20))
                        MediaCard(
                          item: _groupAsItem(group),
                          width: 156,
                          subtitle: '${group.episodes.length} episódios',
                          isFavorite: state.isFavorite(group.key),
                          onToggleFavorite: () =>
                              context.read<AppState>().toggleFavorite(_groupAsItem(group)),
                          onTap: () => _openSeries(context, group),
                        ),
                    ],
                  ),
                if (favorites.isNotEmpty)
                  MediaRow(
                    title: 'Minha lista',
                    height: 240,
                    children: [
                      for (final item in favorites.take(20))
                        MediaCard(
                          item: item,
                          isFavorite: true,
                          onToggleFavorite: () => context.read<AppState>().toggleFavorite(item),
                          onTap: () => _openFavorite(context, state, item),
                        ),
                    ],
                  ),
                ..._movieCategoryRows(context, state, movies),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _movieCategoryRows(BuildContext context, AppState state, List<MediaItem> movies) {
    final counts = <String, List<MediaItem>>{};
    for (final item in movies) {
      counts.putIfAbsent(item.displayGroup, () => []).add(item);
    }
    final entries = counts.entries.where((e) => e.value.length >= 3).take(5).toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return [
      for (final entry in entries)
        MediaRow(
          title: entry.key,
          height: 240,
          children: [
            for (final item in entry.value.take(20))
              MediaCard(
                item: item,
                isFavorite: state.isFavorite(item.id),
                onToggleFavorite: () => context.read<AppState>().toggleFavorite(item),
                onTap: () => openMediaWithServerChoice(context, item),
              ),
          ],
        ),
    ];
  }

  MediaItem? _featured(AppState state) {
    for (final item in state.movieItems) {
      if ((item.backdrop?.isNotEmpty ?? false) || (item.logo?.isNotEmpty ?? false)) return item;
    }
    if (state.movieItems.isNotEmpty) return state.movieItems.first;
    if (state.liveItems.isNotEmpty) return state.liveItems.first;
    if (state.seriesGroups.isNotEmpty) return state.seriesGroups.first.poster;
    return state.items.isEmpty ? null : state.items.first;
  }

  MediaItem _groupAsItem(SeriesGroup group) => seriesGroupAsItem(group);

  void _openFavorite(BuildContext context, AppState state, MediaItem item) {
    if (item.kind == MediaKind.series && item.episode == null) {
      SeriesGroup? group;
      for (final candidate in state.seriesGroups) {
        if (candidate.title != item.title) continue;
        final preview = normalizeText(candidate.group).startsWith('destaques') &&
            candidate.episodes.every((e) => e.season == null && e.episode == null);
        if (preview) {
          group ??= candidate;
          continue;
        }
        group = candidate;
        break;
      }
      if (group != null) {
        final preview = normalizeText(group.group).startsWith('destaques') &&
            group.episodes.every((e) => e.season == null && e.episode == null);
        if (preview) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este título está nos destaques, mas não está disponível na sua lista.'),
            ),
          );
        } else {
          _openSeries(context, group);
        }
        return;
      }
    }
    openMediaWithServerChoice(context, item);
  }

  void _openSeries(BuildContext context, SeriesGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SeriesDetailScreen(group: group)),
    );
  }
}

class _Onboarding extends StatelessWidget {
  const _Onboarding({
    required this.loading,
    required this.onAdd,
    required this.onDemo,
  });

  final bool loading;
  final Future<bool> Function() onAdd;
  final Future<void> Function() onDemo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppLogo(),
                      const SizedBox(height: 34),
                      const Text(
                        'Sua TV, do seu jeito.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 44,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Canais ao vivo, filmes e séries com capa, favoritos, guia de programação '
                        'e “continuar de onde parou”. Traga a sua própria lista M3U — o Nova TV '
                        'organiza tudo em um só lugar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14.5, height: 1.6, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          _FeatureChip(icon: Icons.live_tv_rounded, label: 'Canais ao vivo'),
                          _FeatureChip(icon: Icons.movie_rounded, label: 'Filmes e séries'),
                          _FeatureChip(icon: Icons.favorite_rounded, label: 'Favoritos'),
                          _FeatureChip(icon: Icons.history_rounded, label: 'Continuar assistindo'),
                          _FeatureChip(icon: Icons.calendar_view_day_rounded, label: 'Guia de programação'),
                        ],
                      ),
                      const SizedBox(height: 32),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(),
                        )
                      else
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: () => onAdd(),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Adicionar minha lista M3U'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => onDemo(),
                              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                              label: const Text('Ver demonstração'),
                            ),
                          ],
                        ),
                      const SizedBox(height: 26),
                      const Text(
                        'O Nova TV não fornece conteúdo. Use listas próprias ou licenciadas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Color(0xFF6F7385)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.accent),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFFC9CBD6))),
        ],
      ),
    );
  }
}
