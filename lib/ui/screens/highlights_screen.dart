import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/media_item.dart';
import '../../state/app_state.dart';
import '../flows.dart';
import '../navigation.dart';
import '../widgets/empty_state.dart';
import '../widgets/hero_banner.dart';
import '../widgets/media_card.dart';
import '../widgets/media_row.dart';
import 'series_detail_screen.dart';

/// Aba com os filmes e séries em destaque (ex.: fileiras de "Destaques" da lista).
class HighlightsScreen extends StatelessWidget {
  const HighlightsScreen({super.key, required this.onOpenCatalog});

  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.items.isEmpty) {
      if (state.loading) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 18),
              Text('Carregando destaques…', style: TextStyle(color: AppColors.textMuted)),
            ],
          ),
        );
      }
      return EmptyState(
        icon: Icons.auto_awesome_rounded,
        title: 'Nenhum destaque encontrado',
        message: state.hasSources
            ? 'Sua lista não tem destaques ou ainda está carregando.'
            : 'Adicione uma lista M3U com filmes e séries para começar.',
        action: FilledButton.icon(
          onPressed: () => addOrEditSourceFlow(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar lista'),
        ),
      );
    }

    final movies = _highlightMovies(state);
    final moviesTrending = _moviesForFila(state, 'Em alta');
    final movies2026 = _moviesForFila(state, 'Lançamentos de 2026');
    final seriesTrending = _seriesForFila(state, 'Séries em alta');
    final series2026 = _seriesForFila(state, 'Séries novas de 2026');
    final series = _highlightSeries(state);
    final hasSplitSeries = seriesTrending.isNotEmpty || series2026.isNotEmpty;
    final featured = _featured(state);
    final favorites = state.favorites;

    Widget movieRow(String title, List<MediaItem> items) {
      return MediaRow(
        title: title,
        height: 240,
        onSeeAll: onOpenCatalog,
        children: [
          for (final item in items.take(20))
            MediaCard(
              item: item,
              width: 156,
              isFavorite: state.isFavorite(item.id),
              onToggleFavorite: () => context.read<AppState>().toggleFavorite(item),
              onTap: () => openMediaWithServerChoice(context, item),
            ),
        ],
      );
    }

    Widget seriesRow(String title, List<SeriesGroup> groups) {
      return MediaRow(
        title: title,
        height: 240,
        onSeeAll: onOpenCatalog,
        children: [
          for (final group in groups.take(20))
            Builder(builder: (context) {
              final playable = !_isHighlightOnly(group);
              return MediaCard(
                item: seriesGroupAsItem(group),
                width: 156,
                subtitle: playable
                    ? countLabel(group.episodes.length, 'episódio', 'episódios')
                    : _previewSubtitle(group),
                isFavorite: state.isFavorite(group.key),
                onToggleFavorite: () =>
                    context.read<AppState>().toggleFavorite(seriesGroupAsItem(group)),
                onTap: playable
                    ? () => _openSeries(context, group)
                    : () => _showUnavailable(context, group),
              );
            }),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 6)),
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
        if (state.error != null) SliverToBoxAdapter(child: ErrorBanner(message: state.error!)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (moviesTrending.isNotEmpty) movieRow('Filmes em alta', moviesTrending),
                if (movies2026.isNotEmpty) movieRow('Lançamentos de 2026', movies2026),
                if (moviesTrending.isEmpty && movies2026.isEmpty && movies.isNotEmpty)
                  movieRow('Filmes em destaque', movies),
                if (hasSplitSeries) ...[
                  if (seriesTrending.isNotEmpty) seriesRow('Séries em alta', seriesTrending),
                  if (series2026.isNotEmpty)
                    seriesRow('Séries novas de 2026', series2026),
                ] else if (series.isNotEmpty)
                  seriesRow('Séries em destaque', series),
                if (favorites.isNotEmpty)
                  MediaRow(
                    title: 'Minha lista',
                    height: 240,
                    onSeeAll: onOpenCatalog,
                    children: [
                      for (final item in favorites.take(20))
                        MediaCard(
                          item: item,
                          width: 156,
                          isFavorite: true,
                          onToggleFavorite: () => context.read<AppState>().toggleFavorite(item),
                          onTap: () => item.kind == MediaKind.series && item.episode == null
                              ? _openSeriesForItem(context, state, item)
                              : openMediaWithServerChoice(context, item),
                        ),
                    ],
                  ),
                if (movies.isEmpty && series.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Text(
                      'Sua lista não possui fileiras de destaque. Abra o catálogo para ver tudo.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<MediaItem> _moviesForFila(AppState state, String fila) {
    final wanted = normalizeText('Destaques | $fila');
    final seen = <String>{};
    final items = <MediaItem>[];
    for (final item in state.movieItems) {
      if (normalizeText(item.displayGroup) != wanted) continue;
      final key = _titleKey(item.title);
      if (seen.add(key)) items.add(item);
    }
    return items;
  }

  List<SeriesGroup> _seriesForFila(AppState state, String fila) {
    final wanted = normalizeText('Destaques | $fila');
    final realByTitle = <String, SeriesGroup>{};
    for (final group in state.seriesGroups) {
      if (_isHighlightOnly(group)) continue;
      realByTitle.putIfAbsent(_titleKey(group.title), () => group);
    }

    final seen = <String>{};
    final result = <SeriesGroup>[];
    for (final group in state.seriesGroups) {
      if (normalizeText(group.group) != wanted) continue;
      final key = _titleKey(group.title);
      if (!seen.add(key)) continue;
      result.add(realByTitle[key] ?? group);
    }
    return result;
  }

  bool _isHighlightOnly(SeriesGroup group) {
    if (!normalizeText(group.group).startsWith('destaques')) return false;
    return group.episodes.every((episode) => episode.season == null && episode.episode == null);
  }

  String _titleKey(String title) =>
      normalizeText(title).replaceAll(RegExp(r'\s*\(\d{4}\)$'), '').trim();

  List<MediaItem> _highlightMovies(AppState state) {
    final highlighted = state.movieItems
        .where((item) => normalizeText(item.displayGroup).startsWith('destaques'))
        .toList();
    return highlighted.isNotEmpty ? highlighted : state.movieItems;
  }

  List<SeriesGroup> _highlightSeries(AppState state) {
    final highlighted = state.seriesGroups
        .where((group) => normalizeText(group.group).startsWith('destaques'))
        .toList();
    final actual = state.seriesGroups
        .where((group) => !normalizeText(group.group).startsWith('destaques'))
        .toList();

    if (highlighted.isEmpty) return actual;

    final titles = highlighted
        .map((group) => normalizeText(group.title).replaceAll(RegExp(r'\s*\(\d{4}\)$'), '').trim())
        .toSet();
    final matched = actual.where((group) {
      final title = normalizeText(group.title).replaceAll(RegExp(r'\s*\(\d{4}\)$'), '').trim();
      return titles.contains(title);
    }).toList();

    return matched.isNotEmpty ? matched : actual;
  }

  MediaItem? _featured(AppState state) {
    final movies = _highlightMovies(state);
    for (final item in movies) {
      if ((item.backdrop?.isNotEmpty ?? false) || (item.logo?.isNotEmpty ?? false)) return item;
    }
    if (movies.isNotEmpty) return movies.first;
    final series = _highlightSeries(state);
    if (series.isNotEmpty) return series.first.poster;
    if (state.liveItems.isNotEmpty) return state.liveItems.first;
    return state.items.isEmpty ? null : state.items.first;
  }

  String _previewSubtitle(SeriesGroup group) {
    final year = group.poster.year;
    return year != null ? '$year · em breve' : 'Em breve no catálogo';
  }

  void _showUnavailable(BuildContext context, SeriesGroup group) {
    final poster = group.posterUrl;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (poster.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          poster,
                          width: 64,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(width: 64, height: 96),
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            group.poster.year != null
                                ? '${group.poster.year} · Destaque'
                                : 'Destaque',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Este título está nos destaques, mas ainda não está disponível na sua lista atual.',
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textMuted),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Entendi'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSeries(BuildContext context, SeriesGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SeriesDetailScreen(group: group)),
    );
  }

  void _openSeriesForItem(BuildContext context, AppState state, MediaItem item) {
    var group = state.seriesGroupByKey(item.id);
    if (group == null) {
      for (final candidate in state.seriesGroups) {
        if (candidate.title != item.title) continue;
        if (_isHighlightOnly(candidate)) {
          group ??= candidate;
          continue;
        }
        group = candidate;
        break;
      }
    }
    if (group == null) {
      openMedia(context, item);
    } else if (_isHighlightOnly(group)) {
      _showUnavailable(context, group);
    } else {
      _openSeries(context, group);
    }
  }
}
