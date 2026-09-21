class TransactionEntry {
  final String description;
  final int amount; // amount теперь int (копейки/центы)
  final String categoryId;

  TransactionEntry({
    required this.description,
    required this.amount,
    required this.categoryId,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'amount': amount, // уже int
      'categoryId': categoryId,
    };
  }
} 