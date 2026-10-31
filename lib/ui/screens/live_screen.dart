import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/epg_program.dart';
import '../../data/models/media_item.dart';
import '../../state/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/master_detail_layout.dart';
import 'player_screen.dart';

/// Tela "Ao Vivo": canais à esquerda e vídeo tocando à direita.
///
/// Ao clicar no vídeo, o player abre em tela cheia.
class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key, this.active = true});

  /// Indica se esta aba está visível. Evita tocar áudio em segundo plano.
  final bool active;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final TextEditingController _searchController = TextEditingController();

  Player? _player;
  VideoController? _controller;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  MediaItem? _selected;
  String _category = 'Todos';
  String _query = '';
  int _serverIndex = 0;
  int _openToken = 0;

  bool _playing = false;
  bool _buffering = false;
  String? _error;
  double _volume = 100;
  bool _autoSelectScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) _selectFirstAvailable();
    });
  }

  @override
  void didUpdateWidget(covariant LiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      if (_selected == null) {
        _selectFirstAvailable();
      } else if (_player == null) {
        _ensurePlayer();
        unawaited(_openStream());
      } else {
        unawaited(_player?.play());
      }
    } else if (!widget.active && oldWidget.active) {
      unawaited(_player?.pause());
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Player embutido
  // ---------------------------------------------------------------------------

  void _ensurePlayer() {
    if (_player != null) return;
    final player = Player();
    _player = player;
    _controller = VideoController(player);
    player.setVolume(_volume);

    _subscriptions.add(player.stream.playing.listen((value) {
      if (mounted) setState(() => _playing = value);
    }));
    _subscriptions.add(player.stream.buffering.listen((value) {
      if (mounted) setState(() => _buffering = value);
    }));
    _subscriptions.add(player.stream.error.listen((value) {
      if (!mounted || value.isEmpty) return;
      _handlePlayerError(value);
    }));
  }

  MediaItem? _firstChannel(AppState state) {
    final items = _filteredChannels(state);
    return items.isEmpty ? null : items.first;
  }

  void _selectFirstAvailable() {
    if (_selected != null || !mounted) return;
    final item = _firstChannel(context.read<AppState>());
    if (item != null) _selectChannel(item);
  }

  List<MediaItem> _filteredChannels(AppState state) {
    final query = normalizeText(_query);
    return state.liveItems.where((item) {
      if (_category != 'Todos' && item.displayGroup != _category) return false;
      if (query.isEmpty) return true;
      return normalizeText(item.title).contains(query) ||
          normalizeText(item.displayGroup).contains(query);
    }).toList();
  }

  void _selectChannel(MediaItem item) {
    if (_selected?.id == item.id && _player != null) {
      unawaited(_player?.play());
      return;
    }

    setState(() {
      _selected = item;
      _serverIndex = 0;
      _error = null;
      _buffering = widget.active;
    });

    if (!widget.active) return;
    _ensurePlayer();
    unawaited(_openStream());
  }

  Map<String, String> _headersFor(StreamServer server) {
    final headers = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36',
    };
    final item = _selected;
    if (item?.headers != null) headers.addAll(item!.headers!);
    if (server.headers != null) headers.addAll(server.headers!);
    return headers;
  }

  Future<void> _openStream() async {
    final item = _selected;
    final player = _player;
    if (item == null || player == null) return;

    final servers = item.streamServers;
    if (servers.isEmpty) {
      if (mounted) setState(() => _error = 'Nenhum servidor disponível para este canal.');
      return;
    }

    final index = _serverIndex.clamp(0, servers.length - 1).toInt();
    _serverIndex = index;
    final server = servers[index];
    final token = ++_openToken;

    if (mounted) {
      setState(() {
        _error = null;
        _buffering = true;
      });
    }

    try {
      await player.open(
        Media(server.url, httpHeaders: _headersFor(server)),
        play: true,
      );
      if (!mounted || token != _openToken) return;
      setState(() => _error = null);
    } catch (error) {
      if (!mounted || token != _openToken) return;
      if (_serverIndex + 1 < servers.length) {
        _serverIndex += 1;
        await _openStream();
        return;
      }
      setState(() => _error = 'Não foi possível abrir ${_serverLabel(server, index)}: $error');
    }
  }

  void _handlePlayerError(String message) {
    final item = _selected;
    if (item == null) return;
    final servers = item.streamServers;
    if (_serverIndex + 1 < servers.length) {
      _serverIndex += 1;
      unawaited(_openStream());
      return;
    }
    setState(() => _error = message);
  }

  void _switchServer(int index) {
    final item = _selected;
    if (item == null) return;
    final servers = item.streamServers;
    if (index < 0 || index >= servers.length) return;
    setState(() {
      _serverIndex = index;
      _error = null;
    });
    unawaited(_openStream());
  }

  Future<void> _togglePlay() async {
    if (_player == null) {
      _ensurePlayer();
      await _openStream();
      return;
    }
    await _player!.playOrPause();
  }

  Future<void> _toggleMute() async {
    _volume = _volume == 0 ? 100 : 0;
    await _player?.setVolume(_volume);
    if (mounted) setState(() {});
  }

  Future<void> _openFullscreen() async {
    final item = _selected;
    if (item == null) return;

    await _player?.pause();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          item: item,
          initialStreamIndex: _serverIndex,
        ),
      ),
    );

    if (!mounted) return;
    if (widget.active && _selected?.id == item.id) {
      unawaited(_player?.play());
    }
  }

  String _serverLabel(StreamServer server, int index) {
    final name = server.name?.trim();
    return name == null || name.isEmpty ? 'Servidor ${index + 1}' : server.label;
  }

  // ---------------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = state.liveItems;
    final categories = <String>{for (final item in all) item.displayGroup}.toList()
      ..sort((a, b) => normalizeText(a).compareTo(normalizeText(b)));

    if (_category != 'Todos' && !categories.contains(_category)) {
      _category = 'Todos';
    }

    final filtered = _filteredChannels(state);

    if (widget.active && _selected == null && filtered.isNotEmpty && !_autoSelectScheduled) {
      _autoSelectScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSelectScheduled = false;
        if (mounted && widget.active && _selected == null) {
          _selectChannel(filtered.first);
        }
      });
    }

    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.live_tv_rounded,
        title: 'Nenhum canal ao vivo',
        message: state.hasSources
            ? 'Sua lista não tem canais ou ainda está carregando.'
            : 'Adicione uma lista M3U com canais para começar.',
        action: FilledButton.icon(
          onPressed: () => context.read<AppState>().refresh(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Atualizar listas'),
        ),
      );
    }

    return MasterDetailLayout(
      master: _buildChannelPanel(state, categories, filtered),
      detail: _buildPreview(state),
    );
  }

  Widget _buildChannelPanel(AppState state, List<String> categories, List<MediaItem> filtered) {
    return ColoredBox(
      color: AppColors.surface.withValues(alpha: 0.72),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Canais ao Vivo',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                  ),
                ),
                Text(
                  '${filtered.length}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Buscar canal…',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                  label: 'Todos',
                  selected: _category == 'Todos',
                  onTap: () => setState(() => _category = 'Todos'),
                ),
                for (final category in categories)
                  _CategoryChip(
                    label: category,
                    selected: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhum canal encontrado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 20),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final program = state.epg.nowFor(item.tvgId, item.title);
                      return _ChannelTile(
                        item: item,
                        selected: _selected?.id == item.id,
                        program: program,
                        serverCount: item.streamServers.length,
                        isFavorite: state.isFavorite(item.id),
                        onToggleFavorite: () =>
                            context.read<AppState>().toggleFavorite(item),
                        onTap: () => _selectChannel(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(AppState state) {
    final item = _selected;
    if (item == null) {
      return const ColoredBox(
        color: Color(0xFF050508),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.live_tv_rounded, size: 54, color: Colors.white24),
              SizedBox(height: 14),
              Text(
                'Selecione um canal para assistir',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    final servers = item.streamServers;
    if (servers.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF050508),
        child: Center(
          child: Text(
            'Este canal não possui um link de transmissão.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      );
    }
    final program = state.epg.nowFor(item.tvgId, item.title);

    return ColoredBox(
      color: const Color(0xFF050508),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openFullscreen,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_controller != null)
                    Video(
                      controller: _controller!,
                      controls: NoVideoControls,
                      fit: BoxFit.contain,
                    )
                  else
                    const ColoredBox(color: Colors.black),
                  if (_buffering && _error == null)
                    const Center(
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
                  if (_error != null) _buildPreviewError(servers),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0243A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AO VIVO',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _serverLabel(
                              servers[_serverIndex.clamp(0, servers.length - 1).toInt()],
                              _serverIndex,
                            ),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      tooltip: 'Ampliar vídeo',
                      onPressed: _openFullscreen,
                      icon: const Icon(Icons.open_in_full_rounded, size: 20),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Row(
                      children: [
                        _RoundControl(
                          icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          tooltip: _playing ? 'Pausar' : 'Reproduzir',
                          onTap: _togglePlay,
                        ),
                        const SizedBox(width: 8),
                        _RoundControl(
                          icon: _volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          tooltip: _volume == 0 ? 'Ativar som' : 'Silenciar',
                          onTap: _toggleMute,
                        ),
                        const Spacer(),
                        Text(
                          'Toque no vídeo para ampliar',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildFooter(state, item, servers, program),
        ],
      ),
    );
  }

  Widget _buildPreviewError(List<StreamServer> servers) {
    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.danger),
          const SizedBox(height: 10),
          const Text(
            'Não foi possível sintonizar este canal',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => _switchServer(_serverIndex),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tentar novamente'),
              ),
              if (servers.length > 1)
                OutlinedButton.icon(
                  onPressed: () => _switchServer((_serverIndex + 1) % servers.length),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Outro servidor'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    AppState state,
    MediaItem item,
    List<StreamServer> servers,
    EpgProgram? program,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      program?.title ?? item.displayGroup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Minha lista',
                onPressed: () => context.read<AppState>().toggleFavorite(item),
                icon: Icon(
                  state.isFavorite(item.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 20,
                  color: state.isFavorite(item.id) ? AppColors.accent : AppColors.text,
                ),
              ),
              IconButton(
                tooltip: 'Abrir em tela cheia',
                onPressed: _openFullscreen,
                icon: const Icon(Icons.fullscreen_rounded, size: 22),
              ),
            ],
          ),
          if (servers.length > 1) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.dns_outlined, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 6),
                const Text(
                  'Servidores:',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: servers.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final selected = index == _serverIndex;
                        return ChoiceChip(
                          label: Text(
                            _serverLabel(servers[index], index),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                              color: selected ? Colors.black : AppColors.text,
                            ),
                          ),
                          selected: selected,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => _switchServer(index),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.item,
    required this.selected,
    required this.serverCount,
    required this.onTap,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.program,
  });

  final MediaItem item;
  final bool selected;
  final int serverCount;
  final EpgProgram? program;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.accent.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: item.logo?.isNotEmpty == true
                      ? Image.network(
                          item.logo!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => _ChannelLetter(title: item.title),
                        )
                      : _ChannelLetter(title: item.title),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? AppColors.accent : AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        program?.title ?? item.displayGroup,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (serverCount > 1) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$serverCount',
                      style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                    ),
                  ),
                ],
                if (onToggleFavorite != null)
                  IconButton(
                    tooltip: isFavorite ? 'Remover da Minha lista' : 'Adicionar à Minha lista',
                    onPressed: onToggleFavorite,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    icon: Icon(
                      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 17,
                      color: isFavorite ? AppColors.accent : AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelLetter extends StatelessWidget {
  const _ChannelLetter({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final letter = title.trim().isEmpty ? '?' : title.trim().substring(0, 1).toUpperCase();
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 19, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? Colors.black : AppColors.text,
          ),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
    );
  }
}
