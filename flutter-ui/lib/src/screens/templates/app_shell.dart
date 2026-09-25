import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

import '../../constants/app_strings.dart';
import '../../utils/platform_utils.dart';

class ActionData {
  const ActionData({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

class AppShellTab {
  const AppShellTab({
    required this.label,
    required this.icon,
    required this.builder,
    this.selectedIcon,
    this.appBarActions,
  });

  final String label;
  final Widget icon;
  final Widget? selectedIcon;
  final WidgetBuilder builder;
  final List<ActionData>? appBarActions;
}

/// Renders a navigation rail on web and a bottom navigation bar on mobile.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.tabData,
    this.floatingButtonAction,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppShellTab> tabData;
  final ActionData? floatingButtonAction;

  @override
  Widget build(BuildContext context) {
    return PlatformUtils.isWeb ? _buildWeb(context) : _buildMobile(context);
  }

  Widget? _buildFab() {
    final action = floatingButtonAction;
    if (action == null) return null;
    return FloatingActionButton(
      onPressed: action.onPressed,
      shape: const CircleBorder(),
      tooltip: action.label,
      child: Icon(action.icon),
    );
  }

  List<Widget>? _buildAppBarActions() {
    return tabData[selectedIndex].appBarActions
        ?.map(
          (action) => IconButton(
            icon: Icon(action.icon),
            tooltip: action.label,
            onPressed: action.onPressed,
          ),
        )
        .toList();
  }

  Widget _buildWeb(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 800;

        return Scaffold(
          appBar: AppBar(title: const Text(AppStrings.appTitle)),
          floatingActionButton: _buildFab(),
          body: Row(
            children: [
              NavigationRail(
                extended: isWideScreen,
                minExtendedWidth: 200,
                minWidth: 80,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                labelType: isWideScreen
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.selected,
                backgroundColor: colors.surface,
                selectedIconTheme: IconThemeData(color: colors.primary),
                unselectedIconTheme: IconThemeData(
                  color: colors.onSurfaceVariant,
                ),
                selectedLabelTextStyle: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: colors.onSurfaceVariant,
                ),
                destinations: tabData
                    .map(
                      (tab) => NavigationRailDestination(
                        icon: tab.icon,
                        selectedIcon: tab.selectedIcon,
                        label: Text(tab.label),
                      ),
                    )
                    .toList(),
              ),
              VerticalDivider(
                thickness: 1,
                width: 1,
                color: Theme.of(context).dividerTheme.color,
              ),
              Expanded(child: tabData[selectedIndex].builder(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobile(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text(AppStrings.appTitle),
        trailingActions: _buildAppBarActions(),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: selectedIndex,
          children: tabData.map((tab) => tab.builder(context)).toList(),
        ),
      ),
      bottomNavBar: PlatformNavBar(
        currentIndex: selectedIndex,
        itemChanged: onDestinationSelected,
        items: tabData
            .map(
              (tab) => BottomNavigationBarItem(
                icon: tab.icon,
                activeIcon: tab.selectedIcon ?? tab.icon,
                label: tab.label,
              ),
            )
            .toList(),
      ),
      material: (_, __) => MaterialScaffoldData(
        floatingActionButton: _buildFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
