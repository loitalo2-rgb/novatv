import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/media_item.dart';
import '../../state/app_state.dart';
import '../navigation.dart';
import '../widgets/empty_state.dart';
import '../widgets/media_card.dart';
import '../widgets/media_row.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final results = state.search(_query);
    final live = results.where((item) => item.kind == MediaKind.live).toList();
    final vod = results.where((item) => item.kind != MediaKind.live).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buscar',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Buscar filmes, séries e canais…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar',
                            onPressed: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                if (_query.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${results.length} resultado(s) para “${_query.trim()}”',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_query.trim().isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.manage_search_rounded,
              title: 'Encontre o que quiser assistir',
              message: 'Digite o nome de um canal, filme ou série. A busca percorre todas as suas listas.',
            ),
          )
        else if (results.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Nada encontrado',
              message: 'Tente outro termo ou confira se a lista terminou de carregar.',
            ),
          )
        else ...[
          if (live.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(title: 'Canais', subtitle: '${live.length} encontrados')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 16 / 9,
                ),
                itemCount: live.length,
                itemBuilder: (context, index) {
                  final item = live[index];
                  return LayoutBuilder(
                    builder: (context, constraints) => MediaCard(
                      item: item,
                      width: constraints.maxWidth,
                      isFavorite: state.isFavorite(item.id),
                      onTap: () => openMedia(context, item),
                    ),
                  );
                },
              ),
            ),
          ],
          if (vod.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(title: 'Filmes e séries', subtitle: '${vod.length} encontrados')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 176,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 14,
                  childAspectRatio: 2 / 3,
                ),
                itemCount: vod.length,
                itemBuilder: (context, index) {
                  final item = vod[index];
                  return LayoutBuilder(
                    builder: (context, constraints) => MediaCard(
                      item: item,
                      width: constraints.maxWidth,
                      isFavorite: state.isFavorite(item.id),
                      onTap: () => openMedia(context, item),
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
}
