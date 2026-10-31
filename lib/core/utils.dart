import 'package:intl/intl.dart';

/// Gera um id estável e curto a partir de um texto.
String stableId(String input) {
  var hash = 5381;
  var extra = 0;
  for (final code in input.codeUnits) {
    hash = ((hash << 5) + hash + code) & 0x7fffffff;
    extra = (extra + code) & 0xffff;
  }
  return '${hash.toRadixString(16)}${extra.toRadixString(16)}';
}

String formatDuration(Duration value) {
  if (value.inHours > 0) {
    final h = value.inHours;
    final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${h.toString().padLeft(2, '0')}:$m:$s';
  }
  final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

String formatClock(DateTime date) => DateFormat('HH:mm').format(date.toLocal());
String formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date.toLocal());

String formatRelative(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  return 'há ${diff.inDays} d';
}

/// Monta um contador com singular/plural: `1 canal`, `3 canais`.
String countLabel(int count, String singular, String plural) =>
    '$count ${count == 1 ? singular : plural}';

bool isHlsUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  return path.endsWith('.m3u8') || path.contains('.m3u8?');
}

String normalizeText(String value) {
  const withAccents = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const without = 'aaaaaeeeeiiiiooooouuuucn';
  var result = value.toLowerCase().trim();
  for (var i = 0; i < withAccents.length; i++) {
    result = result.replaceAll(withAccents[i], without[i]);
  }
  return result;
}

/// Remove tags comuns de qualidade/grupo do título de um episódio.
String cleanTitle(String value) {
  return value
      .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
      .replaceAll(RegExp(r'\((?:dublado|legendado|hd|sd|4k|fhd)\)', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'[._]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[\s\-:|]+$'), '')
      .trim();
}
