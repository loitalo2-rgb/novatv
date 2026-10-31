import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/media_item.dart';
import '../../data/models/watch_progress.dart';
import 'focusable_card.dart';

class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 156,
    this.subtitle,
    this.isFavorite = false,
    this.showEpisodeBadge = true,
    this.onToggleFavorite,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final double width;
  final String? subtitle;
  final bool isFavorite;
  final bool showEpisodeBadge;

  /// Quando informado, exibe o coração para adicionar/remover da Minha lista.
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    if (item.kind == MediaKind.live) {
      return _ChannelCard(
        item: item,
        onTap: onTap,
        width: width * 1.35,
        favorite: isFavorite,
        onToggleFavorite: onToggleFavorite,
      );
    }
    return _PosterCard(
      item: item,
      onTap: onTap,
      width: width,
      subtitle: subtitle,
      isFavorite: isFavorite,
      showEpisodeBadge: showEpisodeBadge,
      onToggleFavorite: onToggleFavorite,
    );
  }
}

/// Coração clicável usado sobre os cards para favoritar/desfavoritar.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.onTap,
    this.size = 18,
  });

  final bool isFavorite;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isFavorite ? 'Remover da Minha lista' : 'Adicionar à Minha lista',
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: size,
              color: isFavorite ? AppColors.accent : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.item,
    required this.onTap,
    required this.width,
    this.subtitle,
    this.isFavorite = false,
    this.showEpisodeBadge = true,
    this.onToggleFavorite,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final double width;
  final String? subtitle;
  final bool isFavorite;
  final bool showEpisodeBadge;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.5;
    return FocusableCard(
      onTap: onTap,
      borderRadius: 10,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PosterImage(url: item.logo, title: item.title),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                      Colors.black.withValues(alpha: 0.94),
                    ],
                    stops: const [0.0, 0.45, 0.72, 1.0],
                  ),
                ),
              ),
            ),
            if (showEpisodeBadge && item.episodeLabel.isNotEmpty)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    item.episodeLabel,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                  ),
                ),
              ),
            if (onToggleFavorite != null)
              Positioned(
                top: 6,
                right: 6,
                child: _FavoriteButton(
                  isFavorite: isFavorite,
                  onTap: onToggleFavorite!,
                ),
              )
            else if (isFavorite)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.favorite_rounded, size: 18, color: AppColors.accent),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle ?? item.displayGroup,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.item,
    required this.onTap,
    required this.width,
    this.favorite = false,
    this.onToggleFavorite,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final double width;
  final bool favorite;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final height = width * 9 / 16;
    return FocusableCard(
      onTap: onTap,
      borderRadius: 10,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AppColors.surfaceAlt),
            if (item.logo != null && item.logo!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 34),
                child: Image.network(
                  item.logo!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => _LogoFallback(title: item.title),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 34),
                child: _LogoFallback(title: item.title),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),
            ),
            if (onToggleFavorite != null)
              Positioned(
                top: 5,
                right: 5,
                child: _FavoriteButton(
                  isFavorite: favorite,
                  onTap: onToggleFavorite!,
                  size: 15,
                ),
              )
            else if (favorite)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.favorite_rounded, size: 15, color: AppColors.accent),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.displayGroup,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.url, required this.title});

  final String? url;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _LetterArt(title: title);
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _LetterArt(title: title),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _LetterArt(title: title, dim: true);
      },
    );
  }
}

class _LetterArt extends StatelessWidget {
  const _LetterArt({required this.title, this.dim = false});

  final String title;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final letter = title.trim().isEmpty ? '?' : title.trim().substring(0, 1).toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dim
              ? [AppColors.surfaceHigh, AppColors.surface]
              : [
                  AppColors.violet.withValues(alpha: 0.55),
                  AppColors.surfaceHigh,
                  AppColors.accent.withValues(alpha: 0.35),
                ],
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final letter = title.trim().isEmpty ? '?' : title.trim().substring(0, 1).toUpperCase();
    return Center(
      child: Text(
        letter,
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.35)),
      ),
    );
  }
}

class ContinueCard extends StatelessWidget {
  const ContinueCard({
    super.key,
    required this.progress,
    required this.onTap,
    this.width = 260,
  });

  final WatchProgress progress;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 9 / 16;
    return FocusableCard(
      onTap: onTap,
      borderRadius: 10,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (progress.logo != null && progress.logo!.isNotEmpty)
              Image.network(
                progress.logo!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.surfaceHigh),
              )
            else
              const ColoredBox(color: AppColors.surfaceHigh),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.9)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    progress.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    progress.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress.fraction,
                      minHeight: 3.5,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress.resumeLabel,
                    style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                radius: 13,
                backgroundColor: Color(0xCC000000),
                child: Icon(Icons.play_arrow_rounded, size: 17, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String progressSubtitle(WatchProgress progress) {
  if (progress.seriesTitle != null && progress.seriesTitle!.isNotEmpty) {
    final parts = <String>[progress.seriesTitle!];
    if (progress.season != null) parts.add('T${progress.season!.toString().padLeft(2, '0')}');
    if (progress.episode != null) parts.add('E${progress.episode!.toString().padLeft(2, '0')}');
    return parts.join(' · ');
  }
  return progress.kindLabel;
}

String cardSubtitle(MediaItem item) {
  if (item.seriesTitle != null && item.episode != null) {
    return '${item.seriesTitle} · ${item.episodeLabel}';
  }
  return item.displayGroup;
}

String formatCardCount(int count) => count == 1 ? '1 item' : '$count itens';

String minutesLabel(int minutes) {
  if (minutes <= 0) return 'desativado';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  return hours == 1 ? '1 hora' : '$hours horas';
}

String safeTime(DateTime? value) => value == null ? 'nunca' : formatRelative(value);


