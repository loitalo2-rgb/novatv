import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../data/models/media_item.dart';
import '../state/app_state.dart';
import 'screens/player_screen.dart';

Future<void> openMedia(
  BuildContext context,
  MediaItem item, {
  Duration? startAt,
  int initialStreamIndex = 0,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerScreen(
        item: item,
        startAt: startAt,
        initialStreamIndex: initialStreamIndex,
      ),
    ),
  );
}

/// Nome amigável de um servidor/fonte.
String streamServerLabel(StreamServer server, int index) {
  final name = server.name?.trim();
  return name == null || name.isEmpty ? 'Servidor ${index + 1}' : server.label;
}

/// Detecta o idioma a partir do rótulo da fonte (dub, leg, original…).
String? streamLanguageLabel(StreamServer server) {
  final name = normalizeText(server.name ?? '').trim();
  if (RegExp(r'^dub(lado|ada)?(\s|$)').hasMatch(name)) return 'Dublado';
  if (RegExp(r'^leg(endado|endada)?(\s|$)').hasMatch(name)) return 'Legendado';
  if (RegExp(r'^original(\s|$)').hasMatch(name)) return 'Original';
  return null;
}

/// Rótulo completo para seletores: idioma + nome do servidor quando necessário.
String streamServerOptionLabel(StreamServer server, int index) {
  final language = streamLanguageLabel(server);
  final name = streamServerLabel(server, index);
  if (language == null) return name;
  if (normalizeText(name) == normalizeText(language)) return language;
  return '$language · $name';
}

/// Abre o player permitindo escolher idioma/servidor quando há mais de uma fonte.
Future<void> openMediaWithServerChoice(
  BuildContext context,
  MediaItem item, {
  Duration? startAt,
}) async {
  final servers = item.streamServers;
  if (servers.length <= 1) {
    return openMedia(context, item, startAt: startAt);
  }

  final selected = await showModalBottomSheet<int>(
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
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Escolha o idioma ou servidor para assistir.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < servers.length; index++)
                _ServerOption(
                  server: servers[index],
                  index: index,
                  onTap: () => Navigator.of(sheetContext).pop(index),
                ),
            ],
          ),
        ),
      );
    },
  );

  if (selected == null || !context.mounted) return;
  await openMedia(context, item, startAt: startAt, initialStreamIndex: selected);
}

class _ServerOption extends StatelessWidget {
  const _ServerOption({
    required this.server,
    required this.index,
    required this.onTap,
  });

  final StreamServer server;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final language = streamLanguageLabel(server);
    final host = Uri.tryParse(server.url)?.host ?? server.url;
    final icon = switch (language) {
      'Dublado' => Icons.record_voice_over_rounded,
      'Legendado' => Icons.subtitles_rounded,
      'Original' => Icons.language_rounded,
      _ => Icons.dns_outlined,
    };

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(icon, color: AppColors.accent, size: 21),
      title: Text(
        language ?? streamServerLabel(server, index),
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        language == null
            ? host
            : '${streamServerLabel(server, index)} · $host',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
      ),
      trailing: const Icon(Icons.play_arrow_rounded, size: 20),
    );
  }
}

Future<void> showItemDetails(BuildContext context, MediaItem item) {
  final state = context.read<AppState>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceAlt,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final favorite = state.isFavorite(item.id);
          final progress = state.progressFor(item.id);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 120,
                            height: 180,
                            child: item.logo?.isNotEmpty == true
                                ? Image.network(
                                    item.logo!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const ColoredBox(
                                      color: AppColors.surfaceHigh,
                                      child: Icon(Icons.movie_outlined, color: AppColors.textMuted),
                                    ),
                                  )
                                : const ColoredBox(
                                    color: AppColors.surfaceHigh,
                                    child: Icon(Icons.movie_outlined, color: AppColors.textMuted),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                [
                                  item.displayGroup,
                                  if (item.year != null) '${item.year}',
                                  if (item.episodeLabel.isNotEmpty) item.episodeLabel,
                                ].join(' · '),
                                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                              ),
                              if (item.rating != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFC857)),
                                    const SizedBox(width: 4),
                                    Text(item.rating!.toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 12.5)),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () {
                                      final startAt = progress != null && progress.canResume
                                          ? progress.position
                                          : null;
                                      Navigator.of(sheetContext).pop();
                                      openMedia(context, item, startAt: startAt);
                                    },
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: Text(progress != null && progress.canResume ? 'Continuar' : 'Assistir'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await state.toggleFavorite(item);
                                      setSheetState(() {});
                                    },
                                    icon: Icon(favorite ? Icons.check_rounded : Icons.add_rounded, size: 18),
                                    label: Text(favorite ? 'Na lista' : 'Minha lista'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (item.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 20),
                      Text(
                        item.description!,
                        style: const TextStyle(fontSize: 13, height: 1.55, color: Color(0xFFC9CBD6)),
                      ),
                    ],
                    if (progress != null && progress.canResume) ...[
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.fraction,
                          minHeight: 4,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(progress.resumeLabel,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

