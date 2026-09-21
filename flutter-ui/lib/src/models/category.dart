import 'package:flutter/material.dart';

class Category {
  final String categoryId;
  final String name;
  final String description;
  final String? imageUrl;
  final int rank;
  final String categoryGroupId;
  final String categoryGroupName;
  final String? categoryGroupImageUrl;
  final int categoryGroupRank;
  final IconData iconData;

  Category({
    required this.categoryId,
    required this.name,
    required this.description,
    required this.rank,
    required this.categoryGroupId,
    required this.categoryGroupName,
    required this.categoryGroupRank,
    this.imageUrl,
    this.categoryGroupImageUrl,
    IconData? iconData,
  }) : iconData = iconData ?? getCategoryIcon(name);

  factory Category.fromJson(Map<String, dynamic> json) {
    final name = json['name'] ?? '';
    return Category(
      categoryId: json['categoryId'] ?? '',
      name: name,
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'],
      rank: json['rank'] ?? 0,
      categoryGroupId: json['categoryGroupId'] ?? '',
      categoryGroupName: json['categoryGroupName'] ?? '',
      categoryGroupImageUrl: json['categoryGroupImageUrl'],
      categoryGroupRank: json['categoryGroupRank'] ?? 0,
      iconData: getCategoryIcon(name),
    );
  }

  // Геттеры для обратной совместимости
  String get id => categoryId;
  String get groupId => categoryGroupId;
  String get groupName => categoryGroupName;
  int get groupIndex => categoryGroupRank;

  static IconData getCategoryIcon(String name) {
    final n = name.toLowerCase();
    // Рестораны и еда
    if (n.contains('restaurant') || n.contains('dining')) return Icons.restaurant;
    if (n.contains('coffee') || n.contains('tea')) return Icons.coffee;
    if (n.contains('fast food')) return Icons.fastfood;
    if (n.contains('groceries') || n.contains('household groceries')) return Icons.shopping_cart;
    // Одежда и товары
    if (n.contains('clothing') || n.contains('clothes')) return Icons.checkroom;
    if (n.contains('electronics')) return Icons.devices;
    if (n.contains('home & garden')) return Icons.home;
    if (n.contains('books') || n.contains('magazines')) return Icons.menu_book;
    if (n.contains('school supplies')) return Icons.school;
    // Транспорт
    if (n.contains('gas') || n.contains('fuel')) return Icons.local_gas_station;
    if (n.contains('public transit') || n.contains('transit')) return Icons.directions_bus;
    if (n.contains('commute')) return Icons.directions_car;
    // Развлечения
    if (n.contains('streaming services') || n.contains('streaming')) return Icons.play_circle;
    if (n.contains('movies & cinema')) return Icons.movie;
    if (n.contains('movies')) return Icons.local_movies;
    // Коммунальные услуги
    if (n.contains('electricity')) return Icons.electrical_services;
    if (n.contains('internet') || n.contains('phone')) return Icons.wifi;
    if (n.contains('phone bill')) return Icons.phone_android;
    // Здоровье
    if (n.contains('medical')) return Icons.health_and_safety;
    if (n.contains('fitness') || n.contains('gym')) return Icons.fitness_center;
    if (n.contains('pharmacy')) return Icons.local_pharmacy;
    if (n.contains('personal care')) return Icons.spa;
    // Доходы
    if (n.contains('salary')) return Icons.attach_money;
    if (n.contains('freelance')) return Icons.work;
    if (n.contains('part-time job')) return Icons.work_outline;
    // Финансы
    if (n.contains('bank fees')) return Icons.account_balance;
    if (n.contains('investments')) return Icons.trending_up;
    if (n.contains('atm fees')) return Icons.local_atm;
    // Образование
    if (n.contains('online courses')) return Icons.computer;
    // Подарки и благотворительность
    if (n.contains('gifts') || n.contains('donations')) return Icons.card_giftcard;
    // Личные вещи
    if (n.contains('personal items')) return Icons.person;
    // Прочее
    if (n.contains('other')) return Icons.more_horiz;
    return Icons.category;
  }
} 