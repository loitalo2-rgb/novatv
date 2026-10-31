import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/playlist_source.dart';
import '../state/app_state.dart';
import 'dialogs/source_dialog.dart';

/// Abre o formulário de lista e aplica no estado. Retorna true se salvou.
Future<bool> addOrEditSourceFlow(BuildContext context, {PlaylistSource? existing}) async {
  final state = context.read<AppState>();
  final draft = await showSourceDialog(
    context,
    source: existing,
    localFileName: existing == null ? null : state.localFileName(existing.id),
  );
  if (draft == null || !context.mounted) return false;

  if (existing == null) {
    if (draft.content != null) {
      await state.addSource(
        name: draft.name,
        url: '',
        epgUrl: draft.epgUrl,
        localContent: draft.content,
        localFileName: draft.fileName,
      );
    } else {
      await state.addSource(name: draft.name, url: draft.url, epgUrl: draft.epgUrl);
    }
    return true;
  }

  if (draft.content != null) {
    await state.updateLocalSource(
      existing,
      name: draft.name,
      content: draft.content!,
      fileName: draft.fileName ?? 'lista.m3u',
      epgUrl: draft.epgUrl,
    );
    return true;
  }

  final updated = PlaylistSource(
    id: existing.id,
    name: draft.name,
    url: draft.url,
    epgUrl: draft.epgUrl,
    enabled: existing.enabled,
    lastUpdated: existing.lastUpdated,
    itemCount: existing.itemCount,
    refreshMinutes: existing.refreshMinutes,
  );
  await state.updateSource(updated);
  await state.refreshSource(existing.id);
  return true;
}

Future<void> addDemoFlow(BuildContext context) async {
  await context.read<AppState>().addDemoSource();
}
