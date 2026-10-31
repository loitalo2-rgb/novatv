import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/services/local_file_source.dart';

/// Abre o seletor de arquivo (nativo no Web, caminho digitado no desktop) e
/// devolve a lista M3U escolhida, já validada.
Future<LocalPickedFile?> showImportPlaylistDialog(BuildContext context) {
  return showDialog<LocalPickedFile>(
    context: context,
    builder: (_) => const _ImportPlaylistDialog(),
  );
}

class _ImportPlaylistDialog extends StatefulWidget {
  const _ImportPlaylistDialog();

  @override
  State<_ImportPlaylistDialog> createState() => _ImportPlaylistDialogState();
}

class _ImportPlaylistDialogState extends State<_ImportPlaylistDialog> {
  final TextEditingController _pathController = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _finish(LocalPickedFile? file) async {
    if (!mounted || file == null) return;
    if (!file.content.contains('#EXTM3U') && !file.content.contains('#EXTINF')) {
      setState(() => _error = 'O arquivo não parece uma lista M3U (faltou #EXTM3U/#EXTINF).');
      return;
    }
    Navigator.of(context).pop(file);
  }

  Future<void> _pick() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await _finish(await pickLocalPlaylistFile());
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readPath() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await _finish(await readLocalPlaylistFileAt(_pathController.text));
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is FormatException ? error.message : '$error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importar arquivo'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escolha um arquivo .m3u/.m3u8 salvo no seu computador. '
              'Ele fica guardado só neste aparelho e pode ser atualizado depois.',
              style: TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            if (supportsNativeFilePicker)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(_busy ? 'Lendo arquivo…' : 'Escolher arquivo .m3u'),
                ),
              )
            else ...[
              TextField(
                controller: _pathController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Caminho do arquivo',
                  hintText: r'C:\Users\voce\Downloads\minha-lista.m3u',
                ),
                onSubmitted: (_) => _busy ? null : _readPath(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _readPath,
                  icon: const Icon(Icons.file_open_rounded),
                  label: Text(_busy ? 'Lendo arquivo…' : 'Importar arquivo'),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
