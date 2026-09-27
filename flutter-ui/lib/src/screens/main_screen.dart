import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/amplify_provider.dart';
import '../services/hello_service.dart';
import '../utils/message_utils.dart';
import '../utils/platform_utils.dart';
import 'templates/app_shell.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  Future<void> _onAddPressed() async {
    String message;
    try {
      message = await HelloService().hello();
    } on Exception catch (e) {
      message = '$e';
    }
    if (!mounted) return;
    unawaited(MessageUtils.showMessageSafely(context, message));
  }

  @override
  Widget build(BuildContext context) {
    final addAction = ActionData(
      label: 'Add',
      icon: Icons.add,
      onPressed: _onAddPressed,
    );
    final appBarActions = PlatformUtils.isIOS ? [addAction] : null;

    return AppShell(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      floatingButtonAction: addAction,
      tabData: [
        AppShellTab(
          label: 'Home',
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          appBarActions: appBarActions,
          builder: (_) => const TabPlaceholder(icon: Icons.home, label: 'Home'),
        ),
        AppShellTab(
          label: 'Activity',
          icon: const Icon(Icons.swap_horiz_outlined),
          selectedIcon: const Icon(Icons.swap_horiz),
          appBarActions: appBarActions,
          builder: (_) =>
              const TabPlaceholder(icon: Icons.swap_horiz, label: 'Activity'),
        ),
        AppShellTab(
          label: 'Account',
          icon: const Icon(Icons.account_circle_outlined),
          selectedIcon: const Icon(Icons.account_circle),
          appBarActions: appBarActions,
          builder: (_) => const AccountTab(),
        ),
      ],
    );
  }
}

class TabPlaceholder extends StatelessWidget {
  const TabPlaceholder({
    super.key,
    required this.icon,
    required this.label,
    this.child,
  });

  final IconData icon;
  final String label;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64),
          const SizedBox(height: 16),
          Text(label, style: Theme.of(context).textTheme.headlineSmall),
          if (child != null) ...[const SizedBox(height: 24), child!],
        ],
      ),
    );
  }
}

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Amplify is never configured when sign-in is skipped, so signOut() would
    // throw. Name the stand-in user instead of offering a button that fails.
    if (AppConfig.skipAuth) {
      return TabPlaceholder(
        icon: Icons.account_circle,
        label: 'Account',
        child: Text(
          AppConfig.devUserEmail.isEmpty
              ? 'Signed in is skipped on this environment.'
              : 'Signed in as ${AppConfig.devUserEmail} (sign-in skipped)',
        ),
      );
    }

    return TabPlaceholder(
      icon: Icons.account_circle,
      label: 'Account',
      child: ElevatedButton(
        onPressed: () => unawaited(context.read<AmplifyProvider>().signOut()),
        child: const Text('Sign out'),
      ),
    );
  }
}
