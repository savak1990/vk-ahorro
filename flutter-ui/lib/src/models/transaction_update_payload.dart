class TransactionUpdatePayload {
  final String? userId;
  final String? groupId;
  final String? balanceId;
  final String? type;
  final String? merchantId; // пока не используем
  final String? operationId;
  final DateTime? approvedAt;
  final DateTime? transactedAt;
  final List<Map<String, dynamic>>? transactionEntries;

  const TransactionUpdatePayload({
    this.userId,
    this.groupId,
    this.balanceId,
    this.type,
    this.merchantId,
    this.operationId,
    this.approvedAt,
    this.transactedAt,
    this.transactionEntries,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    void put(String key, dynamic value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      json[key] = value;
    }

    put('userId', userId);
    put('groupId', groupId);
    put('balanceId', balanceId);
    put('type', type);
    json['merchantId'] = merchantId; // Always include merchantId, even if null
    put('operationId', operationId); // Use original operationId from transaction details
    if (approvedAt != null) put('approvedAt', approvedAt!.toUtc().toIso8601String());
    if (transactedAt != null) put('transactedAt', transactedAt!.toUtc().toIso8601String());
    if (transactionEntries != null && transactionEntries!.isNotEmpty) put('transactionEntries', transactionEntries);
    return json;
  }

  TransactionUpdatePayload copyWith({
    String? userId,
    String? groupId,
    String? balanceId,
    String? type,
    String? merchantId,
    String? operationId,
    DateTime? approvedAt,
    DateTime? transactedAt,
    List<Map<String, dynamic>>? transactionEntries,
  }) {
    return TransactionUpdatePayload(
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      balanceId: balanceId ?? this.balanceId,
      type: type ?? this.type,
      merchantId: merchantId ?? this.merchantId,
      operationId: operationId ?? this.operationId,
      approvedAt: approvedAt ?? this.approvedAt,
      transactedAt: transactedAt ?? this.transactedAt,
      transactionEntries: transactionEntries ?? this.transactionEntries,
    );
  }

  // Helper методы для создания transaction entries
  static Map<String, dynamic> createTransactionEntry({
    String? id, // ID для существующих entries, null для новых
    String? description,
    required int amount,
    required String categoryId,
  }) {
    final Map<String, dynamic> entry = {
      'description': description, // Always include description, even if null
      'amount': amount,
      'categoryId': categoryId,
    };
    
    // Include id only if provided (for existing entries)
    if (id != null && id.isNotEmpty) {
      entry['id'] = id;
    }
    
    return entry;
  }

  // Создание payload с одним entry (наиболее частый случай)
  factory TransactionUpdatePayload.withSingleEntry({
    String? userId,
    String? groupId,
    String? balanceId,
    String? type,
    String? merchantId,
    String? operationId,
    DateTime? approvedAt,
    DateTime? transactedAt,
    String? entryId, // ID для существующего entry
    String? entryDescription,
    required int entryAmount,
    required String entryCategoryId,
  }) {
    return TransactionUpdatePayload(
      userId: userId,
      groupId: groupId,
      balanceId: balanceId,
      type: type,
      merchantId: merchantId,
      operationId: operationId,
      approvedAt: approvedAt,
      transactedAt: transactedAt,
      transactionEntries: [
        createTransactionEntry(
          id: entryId,
          description: entryDescription,
          amount: entryAmount,
          categoryId: entryCategoryId,
        ),
      ],
    );
  }
}

