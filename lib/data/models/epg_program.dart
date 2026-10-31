class EpgProgram {
  const EpgProgram({
    required this.channelId,
    required this.title,
    required this.start,
    required this.stop,
    this.description,
  });

  final String channelId;
  final String title;
  final DateTime start;
  final DateTime stop;
  final String? description;

  bool isNow([DateTime? at]) {
    final now = at ?? DateTime.now();
    return !now.isBefore(start) && now.isBefore(stop);
  }

  double progressAt(DateTime at) {
    final total = stop.difference(start).inMilliseconds;
    if (total <= 0) return 0;
    final elapsed = at.difference(start).inMilliseconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

class EpgGuide {
  const EpgGuide({
    required this.byChannel,
    required this.channelNames,
  });

  final Map<String, List<EpgProgram>> byChannel;
  final Map<String, String> channelNames;

  static const empty = EpgGuide(byChannel: {}, channelNames: {});

  bool get isEmpty => byChannel.isEmpty;

  EpgProgram? nowFor(String? tvgId, String? channelName) {
    final now = DateTime.now();
    final keys = <String>[
      if (tvgId != null && tvgId.isNotEmpty) tvgId,
      if (channelName != null && channelName.isNotEmpty) channelName,
    ];
    for (final key in keys) {
      final programs = byChannel[key];
      if (programs == null) continue;
      for (final program in programs) {
        if (program.isNow(now)) return program;
      }
      if (programs.isNotEmpty) {
        final future = programs.where((p) => p.start.isAfter(now)).toList()..sort((a, b) => a.start.compareTo(b.start));
        if (future.isNotEmpty) return future.first;
      }
    }
    return null;
  }

  List<EpgProgram> timelineFor(String? tvgId, String? channelName) {
    final keys = <String>[
      if (tvgId != null && tvgId.isNotEmpty) tvgId,
      if (channelName != null && channelName.isNotEmpty) channelName,
    ];
    for (final key in keys) {
      final programs = byChannel[key];
      if (programs != null && programs.isNotEmpty) {
        return programs;
      }
    }
    return const [];
  }
}
