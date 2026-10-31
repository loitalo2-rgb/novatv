import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/media_item.dart';

class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.item,
    required this.isFavorite,
    required this.onPlay,
    required this.onToggleFavorite,
    required this.onDetails,
  });

  final MediaItem item;
  final bool isFavorite;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final height = (size.width * 0.44).clamp(380.0, 560.0);
    final imageUrl = (item.backdrop?.isNotEmpty ?? false)
        ? item.backdrop
        : (item.logo?.isNotEmpty ?? false)
            ? item.logo
            : null;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _HeroFallback(),
            )
          else
            const _HeroFallback(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.background,
                  AppColors.background.withValues(alpha: 0.82),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.42, 0.92],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  AppColors.background.withValues(alpha: 0.55),
                  AppColors.background,
                ],
                stops: const [0.0, 0.55, 0.82, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 36,
            right: size.width * 0.4,
            bottom: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'EM DESTAQUE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        item.displayGroup.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 46,
                    height: 1.02,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.description?.isNotEmpty == true
                      ? item.description!
                      : (item.kind == MediaKind.live
                          ? 'Assista agora na Nova TV.'
                          : 'Toque em assistir para começar.'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Color(0xFFC9CBD6),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                      label: Text(item.kind == MediaKind.live ? 'Assistir agora' : 'Assistir'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onToggleFavorite,
                      icon: Icon(
                        isFavorite ? Icons.check_rounded : Icons.add_rounded,
                        size: 20,
                      ),
                      label: Text(isFavorite ? 'Na minha lista' : 'Minha lista'),
                    ),
                    IconButton.outlined(
                      onPressed: onDetails,
                      tooltip: 'Mais informações',
                      icon: const Icon(Icons.info_outline_rounded),
                      style: IconButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                        padding: const EdgeInsets.all(14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.violet.withValues(alpha: 0.55),
            AppColors.background,
            AppColors.accent.withValues(alpha: 0.35),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

