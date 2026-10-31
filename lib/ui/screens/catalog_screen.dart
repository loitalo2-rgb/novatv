import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/media_item.dart';
import '../../state/app_state.dart';
import '../flows.dart';
import '../navigation.dart';
import '../widgets/empty_state.dart';
import '../widgets/media_card.dart';
import 'series_detail_screen.dart';

/// Aba com todo o catálogo de filmes e séries.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _kind = 'Todos';
  String _category = 'Todos';
  String _query = '';
  bool _az = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final movies = state.movieItems;
    final series = state.seriesGroups;

    if (movies.isEmpty && series.isEmpty) {
      return EmptyState(
        icon: Icons.video_library_rounded,
        title: 'Catálogo vazio',
        message: state.hasSources
            ? 'Sua lista não tem filmes ou séries ou ainda está carregando.'
            : 'Adicione uma lista M3U com filmes e séries para começar.',
        action: FilledButton.icon(
          onPressed: () => addOrEditSourceFlow(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar lista'),
        ),
      );
    }

    final entries = _entries(movies, series);
    final categories = _categories(entries);
    final effectiveCategory = _category == 'Todos' || categories.contains(_category) ? _category : 'Todos';
    final query = normalizeText(_query);

    final filtered = entries.where((entry) {
      if (effectiveCategory != 'Todos' && entry.item.displayGroup != effectiveCategory) return false;
      if (query.isEmpty) return true;
      return normalizeText(entry.item.title).contains(query) ||
          normalizeText(entry.item.displayGroup).contains(query);
    }).toList()
      ..sort((a, b) {
        final result = normalizeText(a.item.title).compareTo(normalizeText(b.item.title));
        return _az ? result : -result;
      });

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Catálogo',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${countLabel(movies.length, 'filme', 'filmes')} · '
                            '${countLabel(series.length, 'série', 'séries')}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: _az ? 'Ordenar Z–A' : 'Ordenar A–Z',
                      onPressed: () => setState(() => _az = !_az),
                      icon: Icon(_az ? Icons.sort_by_alpha_rounded : Icons.sort_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Filtrar por nome ou categoria…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final kind in const ['Todos', 'Filmes', 'Séries'])
                        _FilterChip(
                          label: kind,
                          selected: _kind == kind,
                          onTap: () => setState(() => _kind = kind),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'Todas as categorias',
                        selected: effectiveCategory == 'Todos',
                        onTap: () => setState(() => _category = 'Todos'),
                      ),
                      for (final category in categories)
                        _FilterChip(
                          label: category,
                          selected: effectiveCategory == category,
                          onTap: () => setState(() => _category = category),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${filtered.length} ${filtered.length == 1 ? 'título' : 'títulos'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.filter_alt_off_rounded,
              title: 'Nada encontrado',
              message: 'Ajuste os filtros ou tente outro termo de busca.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 176,
                mainAxisSpacing: 16,
                crossAxisSpacing: 14,
                childAspectRatio: 2 / 3,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final entry = filtered[index];
                return LayoutBuilder(
                  builder: (context, constraints) => MediaCard(
                    item: entry.item,
                    width: constraints.maxWidth,
                    isFavorite: state.isFavorite(entry.item.id),
                    subtitle: entry.group == null
                        ? null
                        : countLabel(entry.group!.episodes.length, 'episódio', 'episódios'),
                    onToggleFavorite: () => context.read<AppState>().toggleFavorite(entry.item),
                    onTap: () => entry.group == null
                        ? openMediaWithServerChoice(context, entry.item)
                        : _openSeries(context, entry.group!),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  List<_CatalogEntry> _entries(List<MediaItem> movies, List<SeriesGroup> series) {
    final entries = <_CatalogEntry>[];
    final seenMovies = <String>{};
    if (_kind != 'Séries') {
      for (final movie in movies) {
        final key = normalizeText(movie.title);
        if (!seenMovies.add(key)) continue;
        entries.add(_CatalogEntry(item: movie));
      }
    }
    if (_kind != 'Filmes') {
      for (final group in series) {
        final isHighlightOnly = normalizeText(group.group).startsWith('destaques') &&
            group.episodes.every((episode) => episode.season == null && episode.episode == null);
        if (isHighlightOnly) continue;
        entries.add(_CatalogEntry(item: seriesGroupAsItem(group), group: group));
      }
    }
    return entries;
  }

  List<String> _categories(List<_CatalogEntry> entries) {
    final names = <String>{for (final entry in entries) entry.item.displayGroup};
    final sorted = names.toList()..sort((a, b) => normalizeText(a).compareTo(normalizeText(b)));
    return sorted;
  }

  void _openSeries(BuildContext context, SeriesGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SeriesDetailScreen(group: group)),
    );
  }
}

class _CatalogEntry {
  const _CatalogEntry({required this.item, this.group});

  final MediaItem item;
  final SeriesGroup? group;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? Colors.black : AppColors.text,
          ),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
