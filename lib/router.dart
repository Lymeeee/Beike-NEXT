// Copyright (c) 2025, Harry Huang

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'utils/back_handle.dart';
import 'pages/index.dart';
import 'pages/courses/selection/index.dart';
import 'pages/courses/curriculum/index.dart';
import 'pages/courses/exam/index.dart';
import 'pages/courses/grade/index.dart';
import 'pages/courses/account/index.dart';
import 'pages/net/dashboard/index.dart';
import 'pages/net/traffic/index.dart';
import 'pages/sync/index.dart';
import 'pages/more/settings.dart';
import 'pages/more/update.dart';

class _BottomTab {
  final IconData icon;
  final String label;
  final String rootPath;
  final List<String> pathPrefixes;

  const _BottomTab({
    required this.icon,
    required this.label,
    required this.rootPath,
    required this.pathPrefixes,
  });
}

const _bottomTabs = [
  _BottomTab(
    icon: Icons.home,
    label: '首页',
    rootPath: '/',
    pathPrefixes: ['/'],
  ),
  _BottomTab(
    icon: Icons.more_horiz,
    label: '更多',
    rootPath: '/more/settings',
    pathPrefixes: ['/more/', '/sync', '/courses/', '/net/'],
  ),
];

class AppRouter {
  static final router = RootStackRouter.build(
    routes: [
      NamedRouteDef(
        name: 'HomeRoute',
        path: '/',
        builder: (context, data) => MainLayout(child: const HomePage()),
      ),
      NamedRouteDef(
        name: 'CourseAccountRoute',
        path: '/courses/account',
        builder: (context, data) => MainLayout(child: const AccountPage()),
      ),
      NamedRouteDef(
        name: 'CurriculumRoute',
        path: '/courses/curriculum',
        builder: (context, data) => MainLayout(child: const CurriculumPage()),
      ),
      NamedRouteDef(
        name: 'CourseSelectionRoute',
        path: '/courses/selection',
        builder: (context, data) =>
            MainLayout(child: const CourseSelectionPage()),
      ),
      NamedRouteDef(
        name: 'ExamRoute',
        path: '/courses/exam',
        builder: (context, data) => MainLayout(child: const ExamPage()),
      ),
      NamedRouteDef(
        name: 'GradeRoute',
        path: '/courses/grade',
        builder: (context, data) => MainLayout(child: const GradePage()),
      ),
      NamedRouteDef(
        name: 'NetDashboardRoute',
        path: '/net/dashboard',
        builder: (context, data) => MainLayout(child: const NetDashboardPage()),
      ),
      NamedRouteDef(
        name: 'NetTrafficRoute',
        path: '/net/traffic',
        builder: (context, data) => MainLayout(child: const NetTrafficPage()),
      ),
      NamedRouteDef(
        name: 'SettingsRoute',
        path: '/more/settings',
        builder: (context, data) => MainLayout(child: const SettingsPage()),
      ),
      NamedRouteDef(
        name: 'SyncRoute',
        path: '/sync',
        builder: (context, data) => MainLayout(child: const SyncPage()),
      ),
      NamedRouteDef(
        name: 'UpdateRoute',
        path: '/more/update',
        builder: (context, data) => MainLayout(child: const UpdatePage()),
      ),
    ],
  );
}

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  Widget? _cachedChild;
  final GlobalKey _contentKey = GlobalKey();

  String get _currentPath {
    if (context.mounted) {
      return context.routeData.path;
    }
    return '/';
  }

  int get _selectedTabIndex {
    for (int i = 0; i < _bottomTabs.length; i++) {
      for (final prefix in _bottomTabs[i].pathPrefixes) {
        if (prefix == '/' && _currentPath == '/') return i;
        if (prefix != '/' && _currentPath.startsWith(prefix)) return i;
      }
    }
    return 0;
  }

  void _onTabSelected(int index) {
    final tab = _bottomTabs[index];
    final currentTabIndex = _selectedTabIndex;

    if (currentTabIndex == index) {
      // Already on this tab — pop back to root
      if (_currentPath != tab.rootPath) {
        context.router.replacePath(tab.rootPath);
      }
    } else {
      context.router.replacePath(tab.rootPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    _cachedChild ??= widget.child;

    final content = Scaffold(
      body: KeyedSubtree(key: _contentKey, child: _cachedChild!),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: _onTabSelected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _bottomTabs
            .map(
              (tab) => NavigationDestination(
                icon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );

    return _currentPath == '/'
        ? DoubleBackToExitWrapper(child: content)
        : CommonPopWrapper(child: content);
  }
}
