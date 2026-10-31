/// Implementação padrão (sem seletor nativo e sem leitura de arquivos).
library;

import 'local_file_models.dart';

export 'local_file_models.dart';

/// `true` quando o sistema permite abrir o seletor nativo de arquivos.
bool get supportsNativeFilePicker => false;

/// Abre o seletor nativo. Retorna `null` quando o usuário cancela.
Future<LocalPickedFile?> pickLocalPlaylistFile() async => null;

/// Lê um arquivo a partir de um caminho digitado pelo usuário.
Future<LocalPickedFile?> readLocalPlaylistFileAt(String path) async => null;
