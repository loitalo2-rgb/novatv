/// Arquivo escolhido pelo usuário para importar uma lista local.
class LocalPickedFile {
  const LocalPickedFile({required this.name, required this.content});

  /// Nome do arquivo, com extensão (ex.: `minha-lista.m3u`).
  final String name;

  /// Conteúdo completo do arquivo.
  final String content;
}

/// Extrai um nome amigável a partir do nome do arquivo.
String playlistNameFromFile(String fileName) {
  var name = fileName;
  final slash = name.lastIndexOf(RegExp(r'[\\/]'));
  if (slash >= 0) name = name.substring(slash + 1);
  name = name.replaceAll(RegExp(r'\.(m3u8?|txt)$', caseSensitive: false), '');
  name = name.replaceAll(RegExp(r'[._-]+'), ' ').trim();
  return name.isEmpty ? 'Minha lista' : name;
}
