import 'package:ahorro_ui/src/providers/transaction_stats_provider.dart';
import 'package:ahorro_ui/src/widgets/fragments/transaction_stats/transaction_stats_list_view_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TransactionStatsListView extends StatelessWidget {
  const TransactionStatsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionStatsProvider>(
      builder: (context, provider, child) {
        final data = provider.data?.items ?? [];
        final isLoading = provider.loading;

        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (data.isEmpty) {
          return const Center(
            child: Text(
              'No transaction data available',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final item = data[index];
            return TransactionStatsListViewItem(item: item);
          },
        );
      },
    );
  }
}
