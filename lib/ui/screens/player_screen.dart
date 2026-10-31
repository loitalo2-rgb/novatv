import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/media_item.dart';
import '../../state/app_state.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.item, this.startAt, this.initialStreamIndex = 0});

  final MediaItem item;
  final Duration? startAt;
  final int initialStreamIndex;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  AppState? _appState;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100;
  bool _playing = false;
  bool _buffering = true;
  bool _completed = false;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  bool _favorite = false;
  String? _error;
  double? _dragValue;

  Timer? _hideTimer;
  Timer? _saveTimer;
  Duration _lastSaved = Duration.zero;

  bool get _isLive => widget.item.kind == MediaKind.live;
  bool get _canFullscreen =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  int _currentStreamIndex = 0;
  bool _openedOnce = false;

  List<StreamServer> get _servers => widget.item.streamServers;

  Map<String, String> _requestHeadersFor(StreamServer? server) {
    final headers = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36',
    };
    if (widget.item.headers != null) {
      headers.addAll(widget.item.headers!);
    }
    if (server?.headers != null) {
      headers.addAll(server!.headers!);
    }
    return headers;
  }

  String _serverLabel(StreamServer server, int index) {
    final name = server.name?.trim();
    return name == null || name.isEmpty ? 'Servidor ${index + 1}' : server.label;
  }

  @override
  void initState() {
    super.initState();
    _favorite = context.read<AppState>().isFavorite(widget.item.id);
    _player = Player();
    _controller = VideoController(_player);

    _subscriptions.add(_player.stream.playing.listen((value) {
      if (!mounted) return;
      setState(() => _playing = value);
      if (value) _scheduleHide();
    }));
    _subscriptions.add(_player.stream.position.listen((value) {
      if (!mounted || _dragValue != null) return;
      setState(() => _position = value);
    }));
    _subscriptions.add(_player.stream.duration.listen((value) {
      if (!mounted) return;
      setState(() => _duration = value);
    }));
    _subscriptions.add(_player.stream.buffering.listen((value) {
      if (!mounted) return;
      setState(() => _buffering = value);
    }));
    _subscriptions.add(_player.stream.completed.listen((value) {
      if (!mounted) return;
      setState(() => _completed = value);
    }));
    _subscriptions.add(_player.stream.error.listen((value) {
      if (!mounted || value.isEmpty) return;
      // Se falhar e houver outra fonte alternativa para este item, tenta a próxima fonte
      final servers = _servers;
      if (_currentStreamIndex + 1 < servers.length) {
        _currentStreamIndex++;
        _openCurrentStream();
        return;
      }
      setState(() => _error = value);
    }));

    _player.setVolume(_volume);
    if (_canFullscreen) {
      _fullscreen = true;
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    }
    _currentStreamIndex = widget.initialStreamIndex
        .clamp(0, _servers.isEmpty ? 0 : _servers.length - 1)
        .toInt();
    _openCurrentStream();

    _saveTimer = Timer.periodic(const Duration(seconds: 15), (_) => _saveProgress());
    _scheduleHide();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState ??= context.read<AppState>();
  }

  Future<void> _open() async {
    _currentStreamIndex = 0;
    _openedOnce = false;
    await _openCurrentStream();
  }

  Future<void> _openCurrentStream() async {
    final servers = _servers;
    if (servers.isEmpty) {
      setState(() => _error = 'Nenhum link de transmissão disponível para este item.');
      return;
    }

    final index = _currentStreamIndex.clamp(0, servers.length - 1).toInt();
    _currentStreamIndex = index;
    final server = servers[index];

    setState(() {
      _error = null;
      _completed = false;
      _buffering = true;
    });

    final headers = _requestHeadersFor(server);
    final resumeAt = _openedOnce && !_isLive ? _position : widget.startAt;

    try {
      await _player.open(
        Media(server.url, httpHeaders: headers),
        play: true,
      );
      _openedOnce = true;
      if (resumeAt != null && resumeAt > const Duration(seconds: 5)) {
        await _player.seek(resumeAt);
      }
    } catch (error) {
      if (!mounted) return;
      if (_currentStreamIndex + 1 < servers.length) {
        _currentStreamIndex++;
        await _openCurrentStream();
        return;
      }
      setState(() => _error = '$error');
    }
  }

  void _saveProgress() {
    if (_isLive || _duration.inSeconds <= 0) return;
    if ((_position - _lastSaved).abs() < const Duration(seconds: 5)) return;
    _lastSaved = _position;
    unawaited(_appState?.saveProgress(widget.item, _position, _duration));
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_playing) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  Future<void> _togglePlay() async {
    if (_completed) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }
    await _player.playOrPause();
  }

  Future<void> _seekBy(Duration delta) async {
    if (_isLive) return;
    final target = _position + delta;
    final max = _duration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (max > Duration.zero && target > max ? max : target);
    await _player.seek(clamped);
    setState(() => _position = clamped);
    _showControls();
  }

  Future<void> _changeVolume(double delta) async {
    _volume = (_volume + delta).clamp(0.0, 100.0);
    await _player.setVolume(_volume);
    if (mounted) setState(() {});
  }

  Future<void> _toggleFullscreen() async {
    if (!_canFullscreen) return;
    _fullscreen = !_fullscreen;
    await SystemChrome.setEnabledSystemUIMode(
      _fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (mounted) setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isBack = event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack;
    if (!node.hasPrimaryFocus && !isBack) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.mediaPlayPause:
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
        _togglePlay();
        _showControls();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _seekBy(const Duration(seconds: -10));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _seekBy(const Duration(seconds: 10));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _changeVolume(5);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _changeVolume(-5);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyF:
        _toggleFullscreen();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  void dispose() {
    _saveProgress();
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseSubtitle = widget.item.seriesTitle != null
        ? '${widget.item.seriesTitle}${widget.item.episodeLabel.isEmpty ? '' : ' · ${widget.item.episodeLabel}'}'
        : widget.item.displayGroup;
    final servers = _servers;
    final serverSuffix = servers.length > 1
        ? ' · Servidor ${_currentStreamIndex.clamp(0, servers.length - 1) + 1}/${servers.length}'
        : '';
    final subtitle = '$baseSubtitle$serverSuffix';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Video(
              controller: _controller,
              controls: NoVideoControls,
              fit: BoxFit.contain,
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                onDoubleTap: _toggleFullscreen,
              ),
            ),
            if (_buffering && _error == null)
              const Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            if (_error != null) _buildError(),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: _buildControls(subtitle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 42, color: AppColors.danger),
          const SizedBox(height: 14),
          const Text('Não foi possível reproduzir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(String subtitle) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, 60),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xE6000000), Colors.transparent],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Voltar',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 26),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (_isLive) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0243A),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'AO VIVO',
                                style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_servers.length > 1)
                  IconButton(
                    tooltip: 'Trocar servidor',
                    onPressed: _showServers,
                    icon: const Icon(Icons.dns_outlined),
                  ),
                IconButton(
                  tooltip: _favorite ? 'Remover da lista' : 'Adicionar à minha lista',
                  onPressed: () async {
                    await context.read<AppState>().toggleFavorite(widget.item);
                    if (mounted) setState(() => _favorite = !_favorite);
                  },
                  icon: Icon(
                    _favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _favorite ? AppColors.accent : Colors.white,
                  ),
                ),
                IconButton(
                  tooltip: 'Faixas de áudio e legenda',
                  onPressed: _showTracks,
                  icon: const Icon(Icons.subtitles_outlined),
                ),
              ],
            ),
          ),
        ),
        Center(
          child: GestureDetector(
            onTap: () {
              _togglePlay();
              _showControls();
            },
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.52),
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(
                _completed ? Icons.replay_rounded : (_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                size: 42,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(22, 70, 22, MediaQuery.paddingOf(context).bottom + 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xF2000000), Colors.transparent],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isLive) _buildSeekBar(),
                Row(
                  children: [
                    IconButton(
                      tooltip: _volume == 0 ? 'Ativar som' : 'Silenciar',
                      onPressed: () async {
                        if (_volume == 0) {
                          _volume = 100;
                        } else {
                          _volume = 0;
                        }
                        await _player.setVolume(_volume);
                        if (mounted) setState(() {});
                      },
                      icon: Icon(
                        _volume == 0
                            ? Icons.volume_off_rounded
                            : _volume < 50
                                ? Icons.volume_down_rounded
                                : Icons.volume_up_rounded,
                        size: 22,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                           activeTrackColor: AppColors.accent,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: AppColors.accent,
                        ),
                        child: Slider(
                          value: _volume.clamp(0, 100),
                          max: 100,
                          onChanged: (value) async {
                            _volume = value;
                            await _player.setVolume(value);
                            if (mounted) setState(() {});
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_isLive)
                      const Text(
                        'Transmissão ao vivo',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                      )
                    else
                      Text(
                        '${formatDuration(_dragValue != null ? Duration(milliseconds: _dragValue!.round()) : _position)} / ${formatDuration(_duration)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    const Spacer(),
                    if (_servers.length > 1)
                      IconButton(
                        tooltip: 'Trocar servidor',
                        onPressed: _showServers,
                        icon: const Icon(Icons.dns_outlined, size: 21),
                      ),
                    IconButton(
                      tooltip: 'Legenda',
                      onPressed: _showTracks,
                      icon: const Icon(Icons.subtitles_outlined, size: 21),
                    ),
                    if (_canFullscreen)
                      IconButton(
                        tooltip: 'Tela cheia',
                        onPressed: _toggleFullscreen,
                        icon: Icon(
                          _fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                          size: 23,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeekBar() {
    final max = _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;
    final current = (_dragValue ?? _position.inMilliseconds.toDouble()).clamp(0.0, max);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: Colors.white24,
        thumbColor: AppColors.accent,
      ),
      child: Slider(
        value: current,
        max: max,
        onChangeStart: (value) {
          _hideTimer?.cancel();
          setState(() => _dragValue = value);
        },
        onChanged: (value) => setState(() => _dragValue = value),
        onChangeEnd: (value) async {
          await _player.seek(Duration(milliseconds: value.round()));
          if (mounted) {
            setState(() {
              _position = Duration(milliseconds: value.round());
              _dragValue = null;
            });
          }
          _showControls();
        },
      ),
    );
  }

  Future<void> _showServers() async {
    final servers = _servers;
    if (servers.length <= 1) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Escolher servidor',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Se um servidor estiver lento ou fora do ar, troque para outro.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < servers.length; index++)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _switchServer(index);
                    },
                    leading: Icon(
                      index == _currentStreamIndex
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: index == _currentStreamIndex ? AppColors.accent : AppColors.textMuted,
                      size: 20,
                    ),
                    title: Text(
                      _serverLabel(servers[index], index),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      Uri.tryParse(servers[index].url)?.host ?? servers[index].url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _switchServer(int index) {
    final servers = _servers;
    if (index < 0 || index >= servers.length || index == _currentStreamIndex) return;
    _currentStreamIndex = index;
    _openCurrentStream();
    _showControls();
  }

  Future<void> _showTracks() async {
    final tracks = _player.state.tracks;
    final current = _player.state.track;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Áudio', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    for (final track in tracks.audio)
                      _TrackOption(
                        label: _trackLabel(track.title, track.language, track.id),
                        selected: current.audio.id == track.id,
                        onTap: () async {
                          await _player.setAudioTrack(track);
                          setSheetState(() {});
                          setState(() {});
                        },
                      ),
                    const SizedBox(height: 18),
                    const Text('Legenda', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    _TrackOption(
                      label: 'Desligada',
                      selected: current.subtitle.id == 'no',
                      onTap: () async {
                        await _player.setSubtitleTrack(SubtitleTrack.no());
                        setSheetState(() {});
                        setState(() {});
                      },
                    ),
                    for (final track in tracks.subtitle)
                      _TrackOption(
                        label: _trackLabel(track.title, track.language, track.id),
                        selected: current.subtitle.id == track.id,
                        onTap: () async {
                          await _player.setSubtitleTrack(track);
                          setSheetState(() {});
                          setState(() {});
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _trackLabel(String? title, String? language, String id) {
    if (title != null && title.trim().isNotEmpty) return title;
    if (language != null && language.trim().isNotEmpty) return language.toUpperCase();
    return 'Faixa $id';
  }
}

class _TrackOption extends StatelessWidget {
  const _TrackOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(
        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
        color: selected ? AppColors.accent : AppColors.textMuted,
        size: 20,
      ),
      title: Text(label, style: const TextStyle(fontSize: 13.5)),
    );
  }
}
