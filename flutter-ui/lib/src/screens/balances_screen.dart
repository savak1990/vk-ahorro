import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Removed AppColors in favor of Theme.of(context).colorScheme
import '../models/balance.dart';
import '../providers/balances_provider.dart';
import '../widgets/add_balance_form.dart';
import '../widgets/balance_tile.dart';
import '../constants/app_strings.dart';
import '../widgets/typography.dart';
import '../widgets/settings_section_card.dart';

class BalancesScreen extends StatelessWidget {
  const BalancesScreen({super.key});

  // Extracted AppBar builder
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _showAddBalanceSheet(context),
          tooltip: AppStrings.addBalanceTooltip,
        ),
      ],
    );
  }

  // Extracted loading widget
  Widget _buildLoading(BuildContext context) => Column(
        children: [
          _buildHeader(context),
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );

  // Extracted error widget
  Widget _buildError(BuildContext context, String error) => Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Center(child: Text('${AppStrings.errorPrefix} $error')),
          ),
        ],
      );

  // Extracted empty state widget
  Widget _buildEmpty(BuildContext context) => Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Center(
              child: Text(
                AppStrings.noBalances,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      );

  // Extracted header widget
  Widget _buildHeader(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 4),
          HeadlineEmphasizedLarge(text: AppStrings.balancesTitle),
          SizedBox(height: 8),
          LabelEmphasizedMedium(text: AppStrings.balancesSubtitle),
        ],
      ),
    );
  }

  // Extracted list builder
  Widget _buildList(BuildContext context, List<Balance> balances) {
    final provider = Provider.of<BalancesProvider>(context, listen: false);
    final int activeCount = balances.where((b) => b.deletedAt == null).length;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildHeader(context),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SettingsSectionCard(
            margin: const EdgeInsets.only(top: 0, bottom: 32),
            padding: EdgeInsets.zero,
            children: [
              for (final balance in balances)
                BalanceTile(
                  balance: balance,
                  useCardBackground: false,
                  onDelete: (balance.deletedAt != null || activeCount <= 1)
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete balance?'),
                              content: Text('Are you sure you want to delete the balance "${balance.title}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await provider.deleteBalance(balance.balanceId);
                          }
                        },
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddBalanceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return AddBalanceForm();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BalancesProvider>(
      builder: (context, provider, _) {
        debugPrint('BalancesScreen: isLoading=${provider.isLoading}, error=${provider.error}, balancesCount=${provider.balances.length}');
        return Scaffold(
          appBar: _buildAppBar(context),
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: () {
            if (provider.isLoading) {
              return _buildLoading(context);
            }
            if (provider.error != null) {
              return _buildError(context, provider.error!);
            }
            if (provider.balances.isEmpty) {
              return _buildEmpty(context);
            }
            return _buildList(context, provider.balances);
          }(),
        );
      },
    );
  }
} 