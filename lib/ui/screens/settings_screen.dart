import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/playlist_source.dart';
import '../../state/app_state.dart';
import '../flows.dart';
import '../widgets/media_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 60),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ajustes',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Gerencie suas listas, atualização automática e histórico.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 26),
                _SectionCard(
                  title: 'Minhas listas',
                  subtitle: state.sources.length == 1
                      ? '1 lista configurada'
                      : '${state.sources.length} listas configuradas',
                  trailing: FilledButton.icon(
                    onPressed: () => addOrEditSourceFlow(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Adicionar'),
                  ),
                  child: Column(
                    children: [
                      if (state.sources.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            'Nenhuma lista ainda. Adicione um link .m3u para começar.',
                            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ),
                      for (final source in state.sources)
                        _SourceTile(
                          source: source,
                          onEdit: () => addOrEditSourceFlow(context, existing: source),
                          onRefresh: () => context.read<AppState>().refreshSource(source.id),
                          onToggle: (value) => context.read<AppState>().setSourceEnabled(source.id, value),
                          onDelete: () => _deleteSource(context, source),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Atualização automática',
                  subtitle: 'Quando o link da lista mudar, o app busca as novidades sozinho.',
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _refreshValue(state.autoRefreshMinutes),
                          decoration: const InputDecoration(labelText: 'Atualizar a cada'),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Desativado')),
                            DropdownMenuItem(value: 15, child: Text('15 minutos')),
                            DropdownMenuItem(value: 30, child: Text('30 minutos')),
                            DropdownMenuItem(value: 60, child: Text('1 hora')),
                            DropdownMenuItem(value: 120, child: Text('2 horas')),
                            DropdownMenuItem(value: 360, child: Text('6 horas')),
                          ],
                          onChanged: (value) {
                            if (value != null) context.read<AppState>().setAutoRefreshMinutes(value);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        onPressed: state.loading ? null : () => context.read<AppState>().refresh(),
                        icon: state.loading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Atualizar agora'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Metadados (opcional)',
                  subtitle: 'Chave da API do TMDB para capas e sinopses extras. Fica salva só neste aparelho.',
                  child: const _TmdbField(),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Histórico',
                  subtitle: 'Favoritos e pontos de continuação ficam salvos no aparelho.',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _clearHistory(context),
                        icon: const Icon(Icons.history_toggle_off_rounded, size: 18),
                        label: const Text('Limpar continuar assistindo'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _clearFavorites(context),
                        icon: const Icon(Icons.favorite_border_rounded, size: 18),
                        label: const Text('Limpar favoritos'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Sobre',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text('Nova TV', style: TextStyle(fontWeight: FontWeight.w800)),
                          SizedBox(width: 8),
                          Text('1.0.0', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'O Nova TV é um player. Ele não fornece, hospeda nem distribui canais ou filmes. '
                        'Você é responsável pelas listas M3U/EPG que adicionar e por ter autorização para acessá-las.\n\n'
                        'Feito com Flutter + mpv (media_kit), com layout próprio inspirado em serviços de streaming.',
                        style: TextStyle(fontSize: 12.5, height: 1.55, color: AppColors.textMuted),
                      ),
                      if (state.lastRefresh != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Última atualização: ${safeTime(state.lastRefresh)}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF6F7385)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static int _refreshValue(int value) {
    const allowed = [0, 15, 30, 60, 120, 360];
    return allowed.contains(value) ? value : 60;
  }

  Future<void> _deleteSource(BuildContext context, PlaylistSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover lista?'),
        content: Text('“${source.name}” será removida deste aparelho junto com seus itens.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppState>().deleteSource(source.id);
    }
  }

  Future<void> _clearHistory(BuildContext context) async {
    final confirmed = await _confirm(context, 'Limpar histórico?', 'Os pontos de “continuar assistindo” serão apagados.');
    if (confirmed && context.mounted) await context.read<AppState>().clearProgressHistory();
  }

  Future<void> _clearFavorites(BuildContext context) async {
    final confirmed = await _confirm(context, 'Limpar favoritos?', 'Todos os itens da sua lista serão removidos.');
    if (confirmed && context.mounted) await context.read<AppState>().clearFavorites();
  }

  Future<bool> _confirm(BuildContext context, String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirmar')),
        ],
      ),
    );
    return result == true;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textMuted)),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.onEdit,
    required this.onRefresh,
    required this.onToggle,
    required this.onDelete,
  });

  final PlaylistSource source;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final error = source.lastError;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: error == null ? Colors.white.withValues(alpha: 0.06) : AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              source.url.startsWith('demo://')
                  ? Icons.auto_awesome_rounded
                  : source.url.startsWith('local://')
                      ? Icons.folder_rounded
                      : Icons.playlist_play_rounded,
              size: 20,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  source.url.startsWith('demo://')
                      ? 'Lista de demonstração (exemplo)'
                      : source.url.startsWith('local://')
                          ? 'Arquivo local importado'
                          : source.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  error ??
                      '${source.itemCount ?? 0} itens · atualizada ${safeTime(source.lastUpdated)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: error == null ? const Color(0xFF6F7385) : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: source.enabled, onChanged: onToggle),
          PopupMenuButton<String>(
            tooltip: 'Opções',
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'refresh':
                  onRefresh();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'refresh', child: Text('Atualizar agora')),
              PopupMenuItem(value: 'delete', child: Text('Remover')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TmdbField extends StatefulWidget {
  const _TmdbField();

  @override
  State<_TmdbField> createState() => _TmdbFieldState();
}

class _TmdbFieldState extends State<_TmdbField> {
  final _controller = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _controller.text = context.read<AppState>().tmdbKey ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Chave da API TMDB',
              hintText: 'Opcional',
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: () async {
            await context.read<AppState>().setTmdbKey(_controller.text);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chave salva.')));
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

