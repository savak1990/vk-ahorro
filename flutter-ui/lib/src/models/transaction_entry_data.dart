class TransactionEntryData {
  final String groupId;
  final String userId;
  final String balanceId;
  final String transactionId;
  final String transactionEntryId;
  final String type;
  final double amount;
  final String balanceTitle;
  final String balanceCurrency;
  final String categoryName;
  final String? categoryImageUrl;
  final String merchantName;
  final String name;
  final String? merchantImageUrl;
  final String operationId;
  final DateTime approvedAt;
  final DateTime transactedAt;

  TransactionEntryData({
    required this.groupId,
    required this.userId,
    required this.balanceId,
    required this.transactionId,
    required this.transactionEntryId,
    required this.type,
    required this.amount,
    required this.balanceTitle,
    required this.balanceCurrency,
    required this.categoryName,
    this.categoryImageUrl,
    required this.merchantName,
    required this.name,
    this.merchantImageUrl,
    required this.operationId,
    required this.approvedAt,
    required this.transactedAt,
  });

  factory TransactionEntryData.fromJson(Map<String, dynamic> json) {
    // Handle amount as string or number
    final amountValue = json['amount'];
    double amount;
    if (amountValue is String) {
      amount = double.tryParse(amountValue) ?? 0.0;
    } else if (amountValue is num) {
      amount = amountValue.toDouble();
    } else {
      amount = 0.0;
    }
    
    return TransactionEntryData(
      groupId: json['groupId'] ?? '',
      userId: json['userId'] ?? '',
      balanceId: json['balanceId'] ?? '',
      transactionId: json['transactionId'] ?? '',
      transactionEntryId: json['transactionEntryId'] ?? '',
      type: json['type'] ?? '',
      amount: amount / 100, // Divide by 100 for display in euros
      balanceTitle: json['balanceTitle'] ?? '',
      balanceCurrency: json['balanceCurrency'] ?? '',
      categoryName: json['categoryName'] ?? '',
      categoryImageUrl: json['categoryImageUrl'],
      merchantName: json['merchantName'] ?? '',
      name: json['name'] ?? '',
      merchantImageUrl: json['merchantImageUrl'],
      operationId: json['operationId'] ?? '',
      approvedAt: DateTime.tryParse(json['approvedAt'] ?? '') ?? DateTime.now(),
      transactedAt: DateTime.tryParse(json['transactedAt'] ?? '') ?? DateTime.now(),
    );
  }
} 