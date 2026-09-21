import 'package:flutter/material.dart';
import '../models/filter_option.dart';
import 'filter_chips.dart';

class FiltersBottomSheet extends StatefulWidget {
  final List<FilterOption> typeOptions;
  final List<FilterOption> accountOptions;
  final List<FilterOption> categoryOptions;
  final Set<String> initialSelectedTypes;
  final Set<String> initialSelectedAccounts;
  final Set<String> initialSelectedCategories;

  const FiltersBottomSheet({
    super.key,
    required this.typeOptions,
    required this.accountOptions,
    required this.categoryOptions,
    required this.initialSelectedTypes,
    required this.initialSelectedAccounts,
    required this.initialSelectedCategories,
  });

  @override
  _FiltersBottomSheetState createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends State<FiltersBottomSheet> {
  late Set<String> _selectedTypes;
  late Set<String> _selectedAccounts;
  late Set<String> _selectedCategories;

  @override
  void initState() {
    super.initState();
    _selectedTypes = Set.from(widget.initialSelectedTypes);
    _selectedAccounts = Set.from(widget.initialSelectedAccounts);
    _selectedCategories = Set.from(widget.initialSelectedCategories);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    
    // Получаем безопасную область и высоту экрана
    final mediaQuery = MediaQuery.of(context);
    final safeAreaTop = mediaQuery.padding.top;
    final screenHeight = mediaQuery.size.height;
    
    // Рассчитываем максимальную высоту: экран минус safe area сверху минус отступ
    final maxHeight = screenHeight - safeAreaTop - 20;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Фиксированный заголовок
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedTypes.clear();
                      _selectedAccounts.clear();
                      _selectedCategories.clear();
                    });
                  },
                  child: const Text('Reset All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Скроллируемый контент - занимает всё доступное место
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Type'),
                    FilterChips(
                      options: widget.typeOptions,
                      selectedValues: _selectedTypes,
                      onSelectionChanged: (value, selected) {
                        setState(() {
                          if (value == 'all') {
                            _selectedTypes.clear();
                          } else if (selected) {
                            _selectedTypes.add(value);
                          } else {
                            _selectedTypes.remove(value);
                        }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Balance'),
                    FilterChips(
                      options: widget.accountOptions,
                      selectedValues: _selectedAccounts,
                      onSelectionChanged: (value, selected) {
                        setState(() {
                          if (value == 'all') {
                            _selectedAccounts.clear();
                          } else if (selected) {
                            _selectedAccounts.add(value);
                          } else {
                            _selectedAccounts.remove(value);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Category'),
                    FilterChips(
                      options: widget.categoryOptions,
                      selectedValues: _selectedCategories,
                      onSelectionChanged: (value, selected) {
                        setState(() {
                          if (value == 'all') {
                            _selectedCategories.clear();
                          } else if (selected) {
                            _selectedCategories.add(value);
                          } else {
                            _selectedCategories.remove(value);
                          }
                        });
                      },
                    ),
                    // Добавляем дополнительный отступ снизу для скролла
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            
            // Фиксированная кнопка Apply внизу
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'types': _selectedTypes,
                  'accounts': _selectedAccounts,
                  'categories': _selectedCategories,
                });
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text('Apply'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
} 