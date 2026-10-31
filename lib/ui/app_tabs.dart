import 'package:flutter/material.dart';

enum AppTab { home, live, highlights, catalog, favorites, search, settings }

const appTabLabels = <AppTab, String>{
  AppTab.home: 'Início',
  AppTab.live: 'Ao Vivo',
  AppTab.highlights: 'Destaques',
  AppTab.catalog: 'Catálogo',
  AppTab.favorites: 'Favoritos',
  AppTab.search: 'Busca',
  AppTab.settings: 'Ajustes',
};

const appTabIcons = <AppTab, IconData>{
  AppTab.home: Icons.home_rounded,
  AppTab.live: Icons.live_tv_rounded,
  AppTab.highlights: Icons.auto_awesome_rounded,
  AppTab.catalog: Icons.video_library_rounded,
  AppTab.favorites: Icons.favorite_rounded,
  AppTab.search: Icons.search_rounded,
  AppTab.settings: Icons.settings_rounded,
};
