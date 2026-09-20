import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/responsive.dart';
import '../models/navigation_item.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({required this.child, super.key});

  final Widget child;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  bool _collapsed = false;

  static const items = [
    NavigationItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/dashboard',
    ),
    NavigationItem(
      label: 'TG Management',
      icon: Icons.groups_outlined,
      route: '/tg-management',
    ),
    NavigationItem(
      label: 'Student Management',
      icon: Icons.school_outlined,
      route: '/student-management',
    ),
    NavigationItem(
      label: 'Attendance',
      icon: Icons.fact_check_outlined,
      route: '/attendance',
    ),
    NavigationItem(
      label: 'Reports',
      icon: Icons.bar_chart_outlined,
      route: '/reports',
    ),
    NavigationItem(
      label: 'Excel Import',
      icon: Icons.table_view_outlined,
      route: '/excel-import',
    ),
    NavigationItem(
      label: 'Google Connection',
      icon: Icons.cloud_sync_outlined,
      route: '/google-connection',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tablet = Responsive.isTablet(context);
    final mobile = Responsive.isMobile(context);

    if (mobile) {
      return Scaffold(
        appBar: _buildAppBar(context, mobile: true),
        drawer: Drawer(
          child: SafeArea(
            child: _buildSidebar(context, collapsed: false),
          ),
        ),
        body: widget.child,
      );
    }

    final effectiveCollapsed = tablet ? true : _collapsed;

    return Scaffold(
      appBar: _buildAppBar(context),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: effectiveCollapsed
                ? AppConstants.compactSidebarWidth
                : AppConstants.sidebarWidth,
            child: _buildSidebar(
              context,
              collapsed: effectiveCollapsed,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context, {
    bool mobile = false,
  }) {
    final title = _titleForRoute(GoRouterState.of(context).uri.path);

    return AppBar(
      leading: mobile
          ? null
          : IconButton(
              tooltip: _collapsed ? 'Expand sidebar' : 'Collapse sidebar',
              onPressed: () => setState(() => _collapsed = !_collapsed),
              icon: Icon(
                _collapsed ? Icons.menu : Icons.menu_open,
              ),
            ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_outlined),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.person_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(
    BuildContext context, {
    required bool collapsed,
  }) {
    final currentRoute = GoRouterState.of(context).uri.path;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 10 : 14,
        vertical: 18,
      ),
      child: Column(
        crossAxisAlignment:
            collapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (!collapsed)
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 4, 10, 24),
              child: Row(
                children: [
                  _Logo(),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Super TG',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: _Logo(),
            ),
          ...items.map(
            (item) => _SidebarItem(
              item: item,
              selected: currentRoute == item.route,
              collapsed: collapsed,
              onTap: () {
                context.go(item.route);
                if (Responsive.isMobile(context)) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          const Spacer(),
          if (!collapsed)
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'AttendanceMS • Foundation',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _titleForRoute(String route) {
    for (final item in items) {
      if (item.route == route) return item.label;
    }
    return 'Dashboard';
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(
        Icons.how_to_reg_rounded,
        color: Colors.white,
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final NavigationItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Tooltip(
      message: collapsed ? item.label : '',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color:
              selected ? primary.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 46,
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  const SizedBox(width: 13),
                  Icon(
                    item.icon,
                    size: 21,
                    color: selected ? primary : Colors.grey.shade700,
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? primary : Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
