import 'dart:io';

import 'local_file_models.dart';

export 'local_file_models.dart';

bool get supportsNativeFilePicker => false;

Future<LocalPickedFile?> pickLocalPlaylistFile() async => null;

Future<LocalPickedFile?> readLocalPlaylistFileAt(String path) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Informe o caminho do arquivo.');
  }
  final file = File(trimmed);
  if (!await file.exists()) {
    throw FormatException('Arquivo não encontrado: $trimmed');
  }
  final content = await file.readAsString();
  return LocalPickedFile(name: file.uri.pathSegments.last, content: content);
}
