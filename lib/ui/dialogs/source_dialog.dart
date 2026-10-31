import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/playlist_source.dart';
import '../../data/services/local_file_models.dart' show playlistNameFromFile;
import '../../data/services/local_playlist_store.dart';
import 'import_playlist_dialog.dart';

class SourceDraft {
  const SourceDraft({
    required this.name,
    required this.url,
    this.epgUrl,
    this.content,
    this.fileName,
  });

  final String name;
  final String url;
  final String? epgUrl;

  /// Conteúdo de uma lista importada de arquivo (null quando é por link).
  final String? content;

  /// Nome do arquivo importado.
  final String? fileName;
}

Future<SourceDraft?> showSourceDialog(
  BuildContext context, {
  PlaylistSource? source,
  String? localFileName,
}) {
  final nameController = TextEditingController(text: source?.name ?? '');
  final urlController = TextEditingController(
    text: source != null && LocalPlaylistStore.isLocalUrl(source.url) ? '' : (source?.url ?? ''),
  );
  final epgController = TextEditingController(text: source?.epgUrl ?? '');
  final formKey = GlobalKey<FormState>();
  final isLocal = source != null && LocalPlaylistStore.isLocalUrl(source.url);

  return showDialog<SourceDraft>(
    context: context,
    builder: (dialogContext) {
      Future<void> importFile() async {
        final file = await showImportPlaylistDialog(dialogContext);
        if (file == null || !dialogContext.mounted) return;
        final typedName = nameController.text.trim();
        Navigator.of(dialogContext).pop(
          SourceDraft(
            name: typedName.isEmpty ? playlistNameFromFile(file.name) : typedName,
            url: '',
            epgUrl: epgController.text.trim(),
            content: file.content,
            fileName: file.name,
          ),
        );
      }

      return AlertDialog(
        title: Text(source == null ? 'Adicionar lista' : 'Editar lista'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Use o link de uma lista .m3u/.m3u8 ou importe um arquivo do computador. '
                    'A lista fica salva no aparelho e é atualizada automaticamente.',
                    style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: importFile,
                      icon: const Icon(Icons.upload_file_rounded, size: 19),
                      label: Text(isLocal ? 'Trocar arquivo da lista' : 'Importar arquivo .m3u'),
                    ),
                  ),
                  if (isLocal) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181822),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file_outlined, size: 18, color: Color(0xFF00E5A0)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              localFileName ?? 'Arquivo importado',
                              style: const TextStyle(fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: nameController,
                    autofocus: !isLocal,
                    decoration: const InputDecoration(
                      labelText: 'Nome da lista',
                      hintText: 'Ex.: Minha operadora',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Informe um nome.' : null,
                  ),
                  if (!isLocal) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: urlController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Link da lista (.m3u)',
                        hintText: 'https://.../lista.m3u',
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Informe o link da lista ou importe um arquivo.';
                        if (text.startsWith('demo://')) return null;
                        final uri = Uri.tryParse(text);
                        if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
                          return 'Use um link http:// ou https://';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: epgController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Link do guia de programação (opcional)',
                      hintText: 'https://.../guia.xml (XMLTV)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181822),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_user_outlined, size: 17, color: Color(0xFF00E5A0)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'O Nova TV não fornece canais nem filmes. Use apenas conteúdo próprio '
                            'ou listas licenciadas que você tenha autorização para acessar.',
                            style: TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.of(dialogContext).pop(
                SourceDraft(
                  name: nameController.text.trim(),
                  url: urlController.text.trim(),
                  epgUrl: epgController.text.trim(),
                ),
              );
            },
            child: Text(source == null ? 'Adicionar' : 'Salvar'),
          ),
        ],
      );
    },
  );
}
