import 'package:flutter/material.dart';

class ActiveFiltersSummary extends StatelessWidget {
  final Set<String> selectedTypes;
  final Set<String> selectedAccounts;
  final Set<String> selectedCategories;
  final VoidCallback onClear;

  const ActiveFiltersSummary({
    super.key,
    required this.selectedTypes,
    required this.selectedAccounts,
    required this.selectedCategories,
    required this.onClear,
  });

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final filters = <String>[];
    if (selectedTypes.isNotEmpty) {
      filters.add('Type: ${selectedTypes.map(_capitalize).join(', ')}');
    }
    if (selectedAccounts.isNotEmpty) {
      filters.add('Balance: ${selectedAccounts.join(', ')}');
    }
    if (selectedCategories.isNotEmpty) {
      filters.add('Category: ${selectedCategories.join(', ')}');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(filters.join(' • '), overflow: TextOverflow.ellipsis)),
          TextButton(
            onPressed: onClear,
            child: const Text('Clear'),
          )
        ],
      ),
    );
  }
}

