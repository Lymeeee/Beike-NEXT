// Copyright (c) 2025, Harry Huang

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'utils/haptic.dart';
import 'pages/index.dart';
import 'pages/courses/selection/index.dart';
import 'pages/courses/curriculum/index.dart';
import 'pages/courses/exam/index.dart';
import 'pages/courses/grade/index.dart';
import 'pages/courses/account/index.dart';
import 'pages/net/dashboard/index.dart';
import 'pages/net/traffic/index.dart';
import 'pages/net/electricity/index.dart';
import 'pages/net/webvpn/index.dart';
import 'pages/more/settings.dart';
import 'pages/more/update.dart';
import 'pages/empty_classroom/index.dart';

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
    pathPrefixes: ['/more/', '/courses/', '/net/'],
  ),
];

int _lastUserTabIndex = 0;
String _lastPath = '';

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
        name: 'NetElectricityRoute',
        path: '/net/electricity',
        builder: (context, data) => MainLayout(child: const ElectricityPage()),
      ),
      NamedRouteDef(
        name: 'WebVpnRoute',
        path: '/net/webvpn',
        builder: (context, data) => MainLayout(child: const WebVpnPage()),
      ),
      NamedRouteDef(
        name: 'SettingsRoute',
        path: '/more/settings',
        builder: (context, data) => MainLayout(child: const SettingsPage()),
      ),
      NamedRouteDef(
        name: 'UpdateRoute',
        path: '/more/update',
        builder: (context, data) => MainLayout(child: const UpdatePage()),
      ),
      NamedRouteDef(
        name: 'EmptyClassroomRoute',
        path: '/net/empty-classroom',
        builder: (context, data) =>
            MainLayout(child: const EmptyClassroomPage()),
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
  int _activeTab = 0;

  static const _tabPages = <Widget>[
    HomePage(),
    SettingsPage(),
  ];

  String get _path => context.routeData.path;

  void _onTabSelected(int index) {
    Haptics.selection();
    _lastUserTabIndex = index;
    final isOnTabRoot = _bottomTabs.any((t) => t.rootPath == _path);

    if (isOnTabRoot) {
      if (_activeTab != index) setState(() => _activeTab = index);
    } else {
      _activeTab = index;
      context.router.replacePath(_bottomTabs[index].rootPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    final pathChanged = _lastPath != path;
    _lastPath = path;

    final isTabRoot = _bottomTabs.any((t) => t.rootPath == path);

    if (isTabRoot && pathChanged) {
      final tabIndex = _bottomTabs.indexWhere((t) => t.rootPath == path);
      _activeTab = tabIndex;
      _lastUserTabIndex = tabIndex;
    }

    final scaffold = Scaffold(
      body: isTabRoot
          ? ClipRect(
              child: Stack(
                children: List.generate(_tabPages.length, (i) {
                  final isActive = _activeTab == i;
                  return IgnorePointer(
                    ignoring: !isActive,
                    child: AnimatedSlide(
                      offset: isActive
                          ? Offset.zero
                          : Offset(_activeTab > i ? -1.0 : 1.0, 0.0),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: _tabPages[i],
                    ),
                  );
                }),
              ),
            )
          : widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _lastUserTabIndex,
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

    return scaffold;
  }
}
