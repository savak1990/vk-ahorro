import 'package:ahorro_ui/src/providers/balances_provider.dart';
import 'package:ahorro_ui/src/screens/add_transaction_screen.dart';
import 'package:ahorro_ui/src/widgets/fragments/home_tabs/account_tab.dart';
import 'package:ahorro_ui/src/widgets/fragments/home_tabs/home_tab_new.dart';
import 'package:ahorro_ui/src/screens/templates/app_shell.dart';
import 'package:ahorro_ui/src/widgets/fragments/home_tabs/transactions_tab.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/platform_utils.dart';
import '../utils/message_utils.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String? _pendingTransactionType;
  bool _didCheckBalancesForDefaultCurrency = false;

  Future<bool?> _showAddTransactionBottomSheet() async {
    final cs = Theme.of(context).colorScheme;
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AddTransactionScreen(),
    );

    // Handle the result and show appropriate message
    if (result != null && mounted) {
      final bool success = result['success'] ?? false;
      final String message = result['message'] ?? '';

      await MessageUtils.showMessageSafely(
        context,
        message,
        isSuccess: success,
      );
      return success;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const HomeTabNew(),
      TransactionsTab(initialType: _pendingTransactionType),
      const AccountTab(),
    ];

    // Check for absence of active balances and redirect to default currency selection
    final balancesProvider = context.watch<BalancesProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_didCheckBalancesForDefaultCurrency) return;
      if (balancesProvider.isLoading || balancesProvider.errorMessage != null) {
        return;
      }
      if (!balancesProvider.hasData) {
        return; // Wait until balances have been loaded at least once
      }
      final int activeCount = balancesProvider.balances
          .where((b) => b.deletedAt == null)
          .length;
      if (activeCount == 0) {
        _didCheckBalancesForDefaultCurrency = true;
        Navigator.of(context).pushReplacementNamed('/default-balance-currency');
      } else {
        _didCheckBalancesForDefaultCurrency = true;
      }
    });

    return AppShell(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
          if (index != 1) _pendingTransactionType = null;
        });
      },
      tabData: [
        AppShellTab(
          label: 'Home',
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          builder: (context) => screens[0],
          appBarActions: PlatformUtils.isIOS
              ? [
                  ActionData(
                    label: 'Add',
                    icon: Icons.add,
                    onPressed: () => _showAddTransactionBottomSheet(),
                  ),
                ]
              : null,
        ),
        AppShellTab(
          label: 'Transactions',
          icon: const Icon(Icons.swap_horiz_outlined),
          selectedIcon: const Icon(Icons.swap_horiz),
          builder: (context) => screens[1],
          appBarActions: PlatformUtils.isIOS
              ? [
                  ActionData(
                    label: 'Add',
                    icon: Icons.add,
                    onPressed: () => _showAddTransactionBottomSheet(),
                  ),
                ]
              : null,
        ),
        AppShellTab(
          label: 'Account',
          icon: const Icon(Icons.account_circle_outlined),
          selectedIcon: const Icon(Icons.account_circle),
          builder: (context) => screens[2],
          appBarActions: PlatformUtils.isIOS
              ? [
                  ActionData(
                    label: 'Add',
                    icon: Icons.add,
                    onPressed: () => _showAddTransactionBottomSheet(),
                  ),
                ]
              : null,
        ),
      ],
      floatingButtonAction: ActionData(
        label: 'Add',
        icon: Icons.add,
        onPressed: () => _showAddTransactionBottomSheet(),
      ),
    );
  }
}
