import 'package:flutter/material.dart';
import '../models/filter_option.dart';

class FilterChips extends StatelessWidget {
  final List<FilterOption> options;
  final Set<String> selectedValues;
  final Function(String, bool) onSelectionChanged;
  final bool multiSelect;
  final String? title;

  const FilterChips({
    super.key,
    required this.options,
    required this.selectedValues,
    required this.onSelectionChanged,
    this.multiSelect = true,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              title!,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = selectedValues.contains(option.value);
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      Icon(Icons.check, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 4),
                    ],
                    if (option.icon != null) ...[
                      Icon(
                        option.icon,
                        size: 16,
                        color: isSelected 
                            ? colorScheme.primary 
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(option.label),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (option.isAllOption) {
                    onSelectionChanged(option.value, true);
                  } else if (!multiSelect) {
                    onSelectionChanged(option.value, selected);
                  } else {
                    onSelectionChanged(option.value, selected);
                  }
                },
                showCheckmark: false,
                backgroundColor: colorScheme.surface,
                selectedColor: colorScheme.primary.withOpacity(0.15),
                checkmarkColor: colorScheme.primary,
                side: BorderSide(
                  color: isSelected 
                      ? colorScheme.primary 
                      : colorScheme.outline,
                ),
                labelStyle: textTheme.labelLarge?.copyWith(
                  color: isSelected 
                      ? colorScheme.primary 
                      : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
} 