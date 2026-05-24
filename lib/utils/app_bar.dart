// Copyright (c) 2025, Harry Huang

import 'package:flutter/material.dart';

abstract class UnifiedAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool autoImplyLeading;
  final double titleSpacing;
  final TextStyle? titleTextStyle;

  const UnifiedAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.autoImplyLeading = true,
    this.titleSpacing = 8,
    this.titleTextStyle,
  });

  Color getBackgroundColor(BuildContext context);
  Color getForegroundColor(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, style: titleTextStyle),
      titleSpacing: titleSpacing,
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: autoImplyLeading,
      backgroundColor: getBackgroundColor(context),
      foregroundColor: getForegroundColor(context),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 3,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight - 8);
}

class TopAppBar extends UnifiedAppBar {
  const TopAppBar({super.key, super.actions}) : super(title: '大贝壳');

  @override
  Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Color getForegroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.onPrimary;
  }
}

class PageAppBar extends UnifiedAppBar {
  const PageAppBar({
    super.key,
    required super.title,
    super.actions,
    super.leading,
    super.autoImplyLeading = true,
    super.titleSpacing = 8,
    super.titleTextStyle,
  }) : super();

  @override
  Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  @override
  Color getForegroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }
}
