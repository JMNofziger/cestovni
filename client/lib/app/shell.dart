import 'package:flutter/material.dart';

import '../db/app_database.dart';
import 'pages/debug_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';

/// Bottom-nav shell with Home / Settings / Debug tabs. Per ADR 003 and
/// the M0-01 acceptance, this is a navigable shell only — feature
/// surfaces land in later milestones.
class CestovniShell extends StatefulWidget {
  const CestovniShell({super.key, required this.db});

  final AppDatabase db;

  @override
  State<CestovniShell> createState() => _CestovniShellState();
}

class _CestovniShellState extends State<CestovniShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomePage(),
      const SettingsPage(),
      DebugPage(db: widget.db),
    ];
    final titles = ['Cestovni', 'Settings', 'Debug'];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'Settings'),
          NavigationDestination(
              icon: Icon(Icons.bug_report_outlined), label: 'Debug'),
        ],
      ),
    );
  }
}
