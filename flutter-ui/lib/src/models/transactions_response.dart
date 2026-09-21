import 'transaction_entry_data.dart';

class TransactionsResponse {
  final List<TransactionEntryData> transactionEntries;
  final String? nextToken;

  TransactionsResponse({
    required this.transactionEntries,
    this.nextToken,
  });

  factory TransactionsResponse.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List? ?? [];
    return TransactionsResponse(
      transactionEntries: items
          .map((entry) => TransactionEntryData.fromJson(entry))
          .toList(),
      nextToken: json['nextToken'],
    );
  }
} 