import 'package:flutter/material.dart';

class FilterOption {
  final String value;
  final String label;
  final IconData? icon;
  final Color? color;
  final int count;
  final bool isAllOption;

  const FilterOption({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.count = 0,
    this.isAllOption = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterOption && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'FilterOption(value: $value, label: $label, count: $count)';
} 