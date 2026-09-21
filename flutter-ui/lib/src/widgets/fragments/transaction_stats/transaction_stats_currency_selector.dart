import 'package:ahorro_ui/src/models/currencies.dart';
import 'package:ahorro_ui/src/providers/transaction_stats_provider.dart';
import 'package:ahorro_ui/src/widgets/adaptive/adaptive_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TransactionStatsCurrencySelector extends StatelessWidget {
  const TransactionStatsCurrencySelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<TransactionStatsProvider, CurrencyCode>(
      selector: (_, provider) => provider.selectedCurrency,
      builder: (_, selectedCurrency, _) {
        return AdaptiveDropdown<CurrencyCode>(
          items: CurrencyCode.values,
          selectedItem: selectedCurrency,
          onChanged: (value) {
            if (value != null) {
              context.read<TransactionStatsProvider>().selectedCurrency = value;
            }
          },
          itemLabelBuilder: (item) {
            switch (item) {
              case CurrencyCode.eur:
                return 'EUR';
              case CurrencyCode.usd:
                return 'USD';
              case CurrencyCode.gbp:
                return 'GBP';
              case CurrencyCode.jpy:
                return 'JPY';
              case CurrencyCode.aud:
                return 'AUD';
              case CurrencyCode.uah:
                return 'UAH';
              case CurrencyCode.byn:
                return 'BYN';
            }
          },
        );
      },
    );
  }
}
