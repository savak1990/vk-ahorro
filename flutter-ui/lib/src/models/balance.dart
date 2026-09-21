class Balance {
  final String balanceId;
  final String groupId;
  final String userId;
  final String currency;
  final String title;
  final String description;
  final int rank;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Balance({
    required this.balanceId,
    required this.groupId,
    required this.userId,
    required this.currency,
    required this.title,
    required this.description,
    required this.rank,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Balance.fromJson(Map<String, dynamic> json) {
    return Balance(
      balanceId: json['balanceId'] ?? '',
      groupId: json['groupId'] ?? '',
      userId: json['userId'] ?? '',
      currency: json['currency'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      rank: json['rank'] ?? 0,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'balanceId': balanceId,
      'groupId': groupId,
      'userId': userId,
      'currency': currency,
      'title': title,
      'description': description,
      'rank': rank,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  // Геттер для обратной совместимости с id
  String get id => balanceId;

  Balance copyWith({
    String? balanceId,
    String? groupId,
    String? userId,
    String? currency,
    String? title,
    String? description,
    int? rank,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Balance(
      balanceId: balanceId ?? this.balanceId,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      currency: currency ?? this.currency,
      title: title ?? this.title,
      description: description ?? this.description,
      rank: rank ?? this.rank,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Balance &&
          runtimeType == other.runtimeType &&
          balanceId == other.balanceId &&
          groupId == other.groupId &&
          userId == other.userId &&
          currency == other.currency &&
          title == other.title &&
          description == other.description &&
          rank == other.rank &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode =>
      balanceId.hashCode ^
      groupId.hashCode ^
      userId.hashCode ^
      currency.hashCode ^
      title.hashCode ^
      description.hashCode ^
      rank.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      deletedAt.hashCode;

  @override
  String toString() {
    return 'Balance(balanceId: $balanceId, groupId: $groupId, userId: $userId, currency: $currency, title: $title, description: $description, rank: $rank, createdAt: $createdAt, updatedAt: $updatedAt, deletedAt: $deletedAt)';
  }
} 