import 'package:flutter/material.dart';

class TransactionDisplayData {
  final String id;
  final String type;
  final double amount;
  final String category;
  final IconData categoryIcon;
  final String account;
  final String? description;
  final String? merchantName;
  final DateTime date;
  final String currency;

  TransactionDisplayData({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.categoryIcon,
    required this.account,
    this.description,
    this.merchantName,
    required this.date,
    required this.currency,
  });
}

