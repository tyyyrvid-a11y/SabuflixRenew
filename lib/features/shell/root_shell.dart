import 'package:flutter/material.dart';
import '../../core/glass/glass_nav_bar.dart';
import '../../core/glass/glass_side_bar.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';
import '../mylist/my_list_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    SearchScreen(),
    MyListScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Início'),
    NavItem(icon: Icons.search_rounded, activeIcon: Icons.search_rounded, label: 'Buscar'),
    NavItem(icon: Icons.bookmark_border_rounded, activeIcon: Icons.bookmark_rounded, label: 'Minha Lista'),
    NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 600;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Row(
              children: [
                GlassSideBar(
                  items: _items,
                  currentIndex: _index,
                  onTap: (i) => setState(() => _index = i),
                ),
                Expanded(
                  child: IndexedStack(index: _index, children: _screens),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          extendBody: true,
          body: IndexedStack(index: _index, children: _screens),
          bottomNavigationBar: GlassNavBar(
            items: _items,
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
          ),
        );
      },
    );
  }
}
