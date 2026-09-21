class TransactionDetails {
  final String? id;
  final String? groupId;
  final String? userId;
  final String? balanceId;
  final String? balanceTitle; // новое поле из API
  final String? balanceCurrency; // новое поле из API
  final String? operationId;
  final String type;
  final DateTime? transactedAt;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final TransactionBalanceDetails? balance; // legacy объект balance
  final String? merchant;
  final String? merchantId;
  final List<TransactionEntryDetails> entries;

  TransactionDetails({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.balanceId,
    this.balanceTitle,
    this.balanceCurrency,
    required this.operationId,
    required this.type,
    required this.transactedAt,
    required this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.balance,
    required this.merchant,
    required this.merchantId,
    required this.entries,
  });

  factory TransactionDetails.fromJson(Map<String, dynamic> json) {
    final entriesJson = (json['transactionEntries'] as List?) ?? 
                       (json['TransactionEntries'] as List?) ?? const [];
    
    String? merchantString;
    String? merchantId;
    final merchantRaw = json['Merchant'] ?? json['merchant'];
    if (merchantRaw is Map) {
      final m = merchantRaw.cast<String, dynamic>();
      merchantString = m['Name']?.toString() ?? m['name']?.toString();
      merchantId = m['MerchantId']?.toString() ?? m['merchantId']?.toString() ?? 
                   m['ID']?.toString() ?? m['Id']?.toString();
    } else if (merchantRaw != null) {
      merchantString = merchantRaw.toString();
    }
    
    // Также пробуем прочитать из верхнего уровня
    merchantId = merchantId ?? json['MerchantID']?.toString() ?? 
                 json['MerchantId']?.toString() ?? json['merchantId']?.toString();

    return TransactionDetails(
      id: json['transactionId']?.toString() ?? 
          json['ID']?.toString() ?? json['Id']?.toString() ?? json['id']?.toString(),
      groupId: json['groupId']?.toString() ?? 
               json['GroupID']?.toString() ?? json['GroupId']?.toString(),
      userId: json['userId']?.toString() ?? 
              json['UserID']?.toString() ?? json['UserId']?.toString(),
      balanceId: json['balanceId']?.toString() ?? 
                 json['BalanceID']?.toString() ?? json['BalanceId']?.toString(),
      balanceTitle: json['balanceTitle']?.toString(),
      balanceCurrency: json['balanceCurrency']?.toString(),
      operationId: json['operationId']?.toString() ?? 
                   json['OperationID']?.toString() ?? json['OperationId']?.toString(),
      type: (json['type'] ?? json['Type'] ?? '').toString(),
      transactedAt: _tryParseDateTime(json['transactedAt'] ?? json['TransactedAt']),
      approvedAt: _tryParseDateTime(json['approvedAt'] ?? json['ApprovedAt']),
      createdAt: _tryParseDateTime(json['createdAt'] ?? json['CreatedAt']),
      updatedAt: _tryParseDateTime(json['updatedAt'] ?? json['UpdatedAt']),
      deletedAt: _tryParseDateTime(json['deletedAt'] ?? json['DeletedAt']),
      balance: json['Balance'] != null
          ? TransactionBalanceDetails.fromJson(
              (json['Balance'] as Map).cast<String, dynamic>())
          : (json['balanceTitle'] != null && json['balanceCurrency'] != null)
              ? TransactionBalanceDetails(
                  balanceId: json['balanceId']?.toString(),
                  title: json['balanceTitle']?.toString(),
                  currency: json['balanceCurrency']?.toString(),
                )
              : null,
      merchant: merchantString,
      merchantId: merchantId,
      entries: entriesJson
          .map((e) => TransactionEntryDetails.fromJson(
              (e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class TransactionBalanceDetails {
  final String? balanceId;
  final String? title;
  final String? currency;

  const TransactionBalanceDetails({
    this.balanceId,
    this.title,
    this.currency,
  });

  factory TransactionBalanceDetails.fromJson(Map<String, dynamic> json) {
    return TransactionBalanceDetails(
      balanceId: json['BalanceId']?.toString() ?? json['balanceId']?.toString(),
      title: json['Title']?.toString() ?? json['title']?.toString(),
      currency: json['Currency']?.toString() ?? json['currency']?.toString(),
    );
  }
}

class TransactionEntryDetails {
  final String? transactionEntryId; // новое поле из API
  final int amount; // в копейках/центах
  final String? description;
  final String? name;
  final String? categoryId; // прямой categoryId из API
  final String? categoryName; // прямой categoryName из API
  final String? categoryIcon; // прямой categoryIcon из API
  final String? categoryGroupId; // новое поле из API
  final String? categoryGroupName; // новое поле из API
  final String? categoryGroupIcon; // новое поле из API
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt; // поле для отслеживания удаленных entries
  final TransactionCategoryDetails? category; // legacy объект category
  final String? id; // legacy поле

  const TransactionEntryDetails({
    this.transactionEntryId,
    required this.amount,
    this.description,
    this.name,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categoryGroupId,
    this.categoryGroupName,
    this.categoryGroupIcon,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.category,
    this.id,
  });

  factory TransactionEntryDetails.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['Category'];
    return TransactionEntryDetails(
      transactionEntryId: json['transactionEntryId']?.toString(),
      amount: _parseAmountToCents(json['amount'] ?? json['Amount']),
      description: json['description']?.toString() ?? json['Description']?.toString(),
      name: json['Name']?.toString(),
      categoryId: json['categoryId']?.toString() ?? json['CategoryID']?.toString() ?? json['CategoryId']?.toString(),
      categoryName: json['categoryName']?.toString(),
      categoryIcon: json['categoryIcon']?.toString(),
      categoryGroupId: json['categoryGroupId']?.toString(),
      categoryGroupName: json['categoryGroupName']?.toString(),
      categoryGroupIcon: json['categoryGroupIcon']?.toString(),
      createdAt: _tryParseDateTime(json['createdAt'] ?? json['CreatedAt']),
      updatedAt: _tryParseDateTime(json['updatedAt'] ?? json['UpdatedAt']),
      deletedAt: _tryParseDateTime(json['deletedAt'] ?? json['DeletedAt']),
      category: categoryJson is Map<String, dynamic>
          ? TransactionCategoryDetails.fromJson(categoryJson)
          : (json['categoryName'] != null)
              ? TransactionCategoryDetails(
                  categoryId: json['categoryId']?.toString(),
                  name: json['categoryName']?.toString(),
                  categoryNameLegacy: json['categoryName']?.toString(),
                )
              : null,
      id: json['ID']?.toString() ?? json['Id']?.toString() ?? json['transactionEntryId']?.toString(),
    );
  }
}

class TransactionCategoryDetails {
  final String? categoryId;
  final String? name; // новое поле API
  final String? categoryNameLegacy; // legacy поле CategoryName

  const TransactionCategoryDetails({
    this.categoryId,
    this.name,
    this.categoryNameLegacy,
  });

  factory TransactionCategoryDetails.fromJson(Map<String, dynamic> json) {
    return TransactionCategoryDetails(
      categoryId: json['CategoryId']?.toString() ?? json['categoryId']?.toString() ?? json['ID']?.toString(),
      name: json['Name']?.toString(),
      categoryNameLegacy: json['CategoryName']?.toString(),
    );
  }
}

DateTime? _tryParseDateTime(dynamic value) {
  if (value == null) return null;
  try {
    return DateTime.tryParse(value.toString());
  } catch (_) {
    return null;
  }
}

int _parseAmountToCents(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) {
    final parsed = double.tryParse(value);
    return parsed == null ? 0 : parsed.round();
  }
  return 0;
}

