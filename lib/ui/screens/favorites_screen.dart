import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/media_item.dart';
import '../../state/app_state.dart';
import '../navigation.dart';
import '../widgets/empty_state.dart';
import '../widgets/media_card.dart';
import '../widgets/media_row.dart';
import 'series_detail_screen.dart';

/// Tela dedicada a exibir todos os itens salvos na "Minha lista" (Favoritos),
/// organizados por categoria (Canais, Filmes e Séries).
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _filterKind = 'Todos';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allFavorites = state.favorites;

    if (allFavorites.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'Sua lista está vazia',
        message: 'Toque no ícone de coração em qualquer filme, série ou canal para salvar aqui.',
      );
    }

    final query = normalizeText(_query);
    final filtered = allFavorites.where((item) {
      if (query.isNotEmpty) {
        final matchesTitle = normalizeText(item.title).contains(query);
        final matchesGroup = normalizeText(item.displayGroup).contains(query);
        if (!matchesTitle && !matchesGroup) return false;
      }
      if (_filterKind == 'Canais' && item.kind != MediaKind.live) return false;
      if (_filterKind == 'Filmes' && item.kind != MediaKind.movie) return false;
      if (_filterKind == 'Séries' && item.kind != MediaKind.series) return false;
      return true;
    }).toList();

    final liveFavs = filtered.where((item) => item.kind == MediaKind.live).toList();
    final movieFavs = filtered.where((item) => item.kind == MediaKind.movie).toList();
    final seriesFavs = filtered.where((item) => item.kind == MediaKind.series).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 12),
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
                            'Meus Favoritos',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${allFavorites.length} ${allFavorites.length == 1 ? 'item salvo' : 'itens salvos'} na sua lista',
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Filtrar meus favoritos…',
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
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final kind in const ['Todos', 'Canais', 'Filmes', 'Séries'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              kind,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _filterKind == kind ? FontWeight.w800 : FontWeight.w500,
                                color: _filterKind == kind ? Colors.black : AppColors.text,
                              ),
                            ),
                            selected: _filterKind == kind,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _filterKind = kind),
                          ),
                        ),
                    ],
                  ),
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
              title: 'Nenhum favorito encontrado',
              message: 'Tente outro filtro ou termo de busca.',
            ),
          )
        else ...[
          if (liveFavs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Canais Favoritos',
                subtitle: countLabel(liveFavs.length, 'canal', 'canais'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 16 / 9,
                ),
                itemCount: liveFavs.length,
                itemBuilder: (context, index) {
                  final item = liveFavs[index];
                  return LayoutBuilder(
                    builder: (context, constraints) => MediaCard(
                      item: item,
                      width: constraints.maxWidth,
                      isFavorite: true,
                      onToggleFavorite: () => state.toggleFavorite(item),
                      onTap: () => openMedia(context, item),
                    ),
                  );
                },
              ),
            ),
          ],
          if (movieFavs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Filmes Favoritos',
                subtitle: countLabel(movieFavs.length, 'filme', 'filmes'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 176,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 14,
                  childAspectRatio: 2 / 3,
                ),
                itemCount: movieFavs.length,
                itemBuilder: (context, index) {
                  final item = movieFavs[index];
                  return LayoutBuilder(
                    builder: (context, constraints) => MediaCard(
                      item: item,
                      width: constraints.maxWidth,
                      isFavorite: true,
                      onToggleFavorite: () => state.toggleFavorite(item),
                      onTap: () => openMediaWithServerChoice(context, item),
                    ),
                  );
                },
              ),
            ),
          ],
          if (seriesFavs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Séries Favoritas',
                subtitle: countLabel(seriesFavs.length, 'série', 'séries'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 176,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 14,
                  childAspectRatio: 2 / 3,
                ),
                itemCount: seriesFavs.length,
                itemBuilder: (context, index) {
                  final item = seriesFavs[index];
                  return LayoutBuilder(
                    builder: (context, constraints) => MediaCard(
                      item: item,
                      width: constraints.maxWidth,
                      isFavorite: true,
                      onToggleFavorite: () => state.toggleFavorite(item),
                      onTap: () => _openSeriesForItem(context, state, item),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ],
    );
  }

  void _openSeriesForItem(BuildContext context, AppState state, MediaItem item) {
    SeriesGroup? group = state.seriesGroupByKey(item.id);
    if (group == null) {
      for (final candidate in state.seriesGroups) {
        if (candidate.title == item.title) {
          group = candidate;
          break;
        }
      }
    }

    if (group != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SeriesDetailScreen(group: group!)),
      );
    } else {
      openMediaWithServerChoice(context, item);
    }
  }
}
