import 'package:flutter/material.dart';

import 'home_page.dart';
import 'records_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';

/// 底部导航主框架，IndexedStack 保持各页状态
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [
    HomePage(),
    RecordsPage(),
    StatsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note), label: '记一笔'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: '流水'),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
