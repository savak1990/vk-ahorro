import 'package:ahorro_ui/src/widgets/fragments/transaction_stats/transaction_stats_fragment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';

class TransactionStatsScreen extends StatelessWidget {
  const TransactionStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlatformScaffold(
      appBar: PlatformAppBar(title: Text('Statistics')),
      body: SafeArea(
        child: TransactionStatsFragment(
          showFullscreenButton: false,
          showListView: true,
        ),
      ),
    );
  }
}
