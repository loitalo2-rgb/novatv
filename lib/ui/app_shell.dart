import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/app_state.dart';
import 'app_tabs.dart';
import 'screens/catalog_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/highlights_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/app_logo.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _select(AppTab tab) => setState(() => _index = tab.index);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final state = context.watch<AppState>();
    final screens = <Widget>[
      HomeScreen(onNavigate: _select),
      LiveScreen(active: _index == AppTab.live.index),
      HighlightsScreen(onOpenCatalog: () => _select(AppTab.catalog)),
      const CatalogScreen(),
      const FavoritesScreen(),
      const SearchScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.1),
            radius: 1.4,
            colors: [Color(0xFF15152A), AppColors.background],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (wide) _TopNav(
                index: _index,
                loading: state.loading,
                onSelect: _select,
                onRefresh: () => context.read<AppState>().refresh(),
              ),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: screens,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              height: 68,
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.accent.withValues(alpha: 0.18),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Início'),
                NavigationDestination(icon: Icon(Icons.live_tv_outlined), selectedIcon: Icon(Icons.live_tv_rounded), label: 'Ao Vivo'),
                NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome_rounded), label: 'Destaques'),
                NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library_rounded), label: 'Catálogo'),
                NavigationDestination(icon: Icon(Icons.favorite_outline_rounded), selectedIcon: Icon(Icons.favorite_rounded), label: 'Favoritos'),
                NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Buscar'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Ajustes'),
              ],
            ),
    );
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav({
    required this.index,
    required this.loading,
    required this.onSelect,
    required this.onRefresh,
  });

  final int index;
  final bool loading;
  final ValueChanged<AppTab> onSelect;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      child: Row(
        children: [
          const AppLogo(),
          const SizedBox(width: 30),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in AppTab.values)
                    if (tab != AppTab.settings)
                      _NavItem(
                        label: appTabLabels[tab]!,
                        selected: index == tab.index,
                        onTap: () => onSelect(tab),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Atualizar listas',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 21),
            ),
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => onSelect(AppTab.settings),
            icon: Icon(
              index == AppTab.settings.index ? Icons.settings_rounded : Icons.settings_outlined,
              size: 21,
              color: index == AppTab.settings.index ? AppColors.accent : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected ? AppColors.text : AppColors.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              width: selected ? 18 : 0,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
