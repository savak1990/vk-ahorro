import 'package:ahorro_ui/src/constants/app_strings.dart';
import 'package:ahorro_ui/src/utils/platform_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

/// Represents the main action button data.
class ActionData {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const ActionData({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

/// Represents a single tab in the application's shell/navigation.
///
/// Each tab contains a label and icons used in navigation and a `builder`
/// that produces the tab's content when selected. Instances of this class
/// are provided to `AppShell` via the `tabData` list.
class AppShellTab {
  final String label;
  final Widget icon;
  final Widget? selectedIcon;
  final WidgetBuilder builder;
  final List<ActionData>? appBarActions;

  const AppShellTab({
    required this.label,
    required this.icon,
    required this.builder,
    this.selectedIcon,
    this.appBarActions,
  });
}

/// Platform-adaptive application shell that manages top-level navigation.
///
/// `AppShell` renders the appropriate navigation UI depending on the
/// platform/viewport: a `NavigationRail` for web/wide screens and a
/// `PlatformNavBar` for mobile. Supply the currently selected index,
/// an `onDestinationSelected` callback and a list of `AppShellTab`s to
/// provide the tab content and navigation items.
class AppShell extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;
  final List<AppShellTab> tabData;
  final ActionData? floatingButtonAction;

  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.tabData,
    this.floatingButtonAction,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isWeb) {
      return _buildWebAppShell(context);
    } else {
      return _buildMobileAppShell(context);
    }
  }

  Widget _buildWebAppShell(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 800;

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                extended: isWideScreen,
                minExtendedWidth: 200,
                minWidth: 80,
                selectedIndex: widget.selectedIndex,
                onDestinationSelected: widget.onDestinationSelected,
                labelType: isWideScreen
                    ? NavigationRailLabelType
                          .none // Исправлено: none для extended
                    : NavigationRailLabelType.selected,
                destinations: widget.tabData.map((tab) {
                  return NavigationRailDestination(
                    icon: tab.icon,
                    selectedIcon: tab.selectedIcon,
                    label: Text(tab.label),
                  );
                }).toList(),
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedIconTheme: IconThemeData(
                  color: Theme.of(context).colorScheme.primary,
                ),
                unselectedIconTheme: IconThemeData(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                selectedLabelTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              VerticalDivider(
                thickness: 1,
                width: 1,
                color: Theme.of(context).dividerTheme.color,
              ),
              Expanded(
                child: widget.tabData[widget.selectedIndex].builder(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileAppShell(BuildContext context) {
    return PlatformScaffold(
      body: SafeArea(
        child: IndexedStack(
          index: widget.selectedIndex,
          children: widget.tabData.map((tab) => tab.builder(context)).toList(),
        ),
      ),
      bottomNavBar: PlatformNavBar(
        currentIndex: widget.selectedIndex,
        itemChanged: widget.onDestinationSelected,
        items: widget.tabData.map((tab) {
          return BottomNavigationBarItem(
            icon: tab.icon,
            activeIcon: tab.selectedIcon ?? tab.icon,
            label: tab.label,
          );
        }).toList(),
      ),
      material: (_, __) => MaterialScaffoldData(
        floatingActionButton: FloatingActionButton(
          onPressed: widget.floatingButtonAction?.onPressed,
          shape: const CircleBorder(),
          tooltip: widget.floatingButtonAction?.label,
          child: Icon(widget.floatingButtonAction?.icon),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
      appBar: PlatformAppBar(
        title: const Text(AppStrings.appTitle),
        trailingActions: widget.tabData[widget.selectedIndex].appBarActions
            ?.map(
              (action) => IconButton(
                icon: Icon(action.icon),
                tooltip: action.label,
                onPressed: action.onPressed,
              ),
            )
            .toList(),
      ),
    );
  }
}
