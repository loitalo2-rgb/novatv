import 'dart:convert';
import '../models/epg_program.dart';

class SaimoEpgParser {
  static EpgGuide parse(String jsonContent) {
    try {
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;
      final canais = data['canais'] as Map<String, dynamic>? ?? {};

      final Map<String, List<EpgProgram>> byChannel = {};
      final Map<String, String> channelNames = {};

      canais.forEach((channelName, programsList) {
        if (programsList is List) {
          final List<EpgProgram> programs = [];
          for (final item in programsList) {
            if (item is List && item.length >= 3) {
              final title = item[0].toString();
              final startTs = int.tryParse(item[1].toString());
              final stopTs = int.tryParse(item[2].toString());
              final desc = item.length >= 4 ? item[3].toString() : null;

              if (startTs != null && stopTs != null) {
                programs.add(EpgProgram(
                  channelId: channelName,
                  title: title,
                  start: DateTime.fromMillisecondsSinceEpoch(startTs * 1000),
                  stop: DateTime.fromMillisecondsSinceEpoch(stopTs * 1000),
                  description: desc,
                ));
              }
            }
          }
          byChannel[channelName] = programs;
          channelNames[channelName] = channelName;
        }
      });

      return EpgGuide(byChannel: byChannel, channelNames: channelNames);
    } catch (e) {
      return EpgGuide.empty;
    }
  }
}
