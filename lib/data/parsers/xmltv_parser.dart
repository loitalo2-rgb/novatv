import 'package:xml/xml.dart';

import '../models/epg_program.dart';

class XmltvParser {
  const XmltvParser._();

  static EpgGuide parse(String content) {
    final document = XmlDocument.parse(content);
    final channelNames = <String, String>{};

    for (final channel in document.findAllElements('channel')) {
      final id = channel.getAttribute('id');
      if (id == null || id.isEmpty) continue;
      final names = channel.findElements('display-name').map((e) => e.innerText.trim()).where((e) => e.isNotEmpty);
      if (names.isNotEmpty) channelNames[id] = names.first;
    }

    final byChannel = <String, List<EpgProgram>>{};
    for (final programme in document.findAllElements('programme')) {
      final channelId = programme.getAttribute('channel');
      final start = _parseTime(programme.getAttribute('start'));
      final stop = _parseTime(programme.getAttribute('stop'));
      if (channelId == null || start == null || stop == null) continue;

      final title = programme.findElements('title').map((e) => e.innerText.trim()).where((e) => e.isNotEmpty);
      final description = programme.findElements('desc').map((e) => e.innerText.trim()).where((e) => e.isNotEmpty);

      byChannel.putIfAbsent(channelId, () => []).add(EpgProgram(
            channelId: channelId,
            title: title.isEmpty ? 'Sem informação' : title.first,
            description: description.isEmpty ? null : description.first,
            start: start,
            stop: stop,
          ));
    }

    for (final programs in byChannel.values) {
      programs.sort((a, b) => a.start.compareTo(b.start));
      // Mantém apenas o que já passou nas últimas 3h e o futuro (evita guias gigantes).
      final cutoff = DateTime.now().subtract(const Duration(hours: 3));
      programs.removeWhere((p) => p.stop.isBefore(cutoff));
    }

    return EpgGuide(byChannel: byChannel, channelNames: channelNames);
  }

  static DateTime? _parseTime(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-]\d{4})?').firstMatch(raw.trim());
    if (match == null) return null;

    final year = int.tryParse(match.group(1)!) ?? 0;
    final month = int.tryParse(match.group(2)!) ?? 1;
    final day = int.tryParse(match.group(3)!) ?? 1;
    final hour = int.tryParse(match.group(4)!) ?? 0;
    final minute = int.tryParse(match.group(5)!) ?? 0;
    final second = int.tryParse(match.group(6) ?? '0') ?? 0;

    var utc = DateTime.utc(year, month, day, hour, minute, second);
    final offset = match.group(7);
    if (offset != null) {
      final sign = offset.startsWith('-') ? -1 : 1;
      final hours = int.tryParse(offset.substring(1, 3)) ?? 0;
      final minutes = int.tryParse(offset.substring(3, 5)) ?? 0;
      utc = utc.subtract(Duration(minutes: sign * (hours * 60 + minutes)));
    }
    return utc.toLocal();
  }
}
