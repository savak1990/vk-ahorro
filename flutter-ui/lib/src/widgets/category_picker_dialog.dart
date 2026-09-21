import 'package:flutter/material.dart';
import '../models/category.dart';
import '../constants/app_typography.dart';
import '../providers/categories_provider.dart';
import 'package:provider/provider.dart';

class CategoryPickerDialog extends StatefulWidget {
  final String? selectedCategoryId;

  const CategoryPickerDialog({
    super.key,
    this.selectedCategoryId,
  });

  @override
  State<CategoryPickerDialog> createState() => _CategoryPickerDialogState();
}

class _CategoryPickerDialogState extends State<CategoryPickerDialog>
    with TickerProviderStateMixin {
  String _search = '';
  String? _selectedId;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedCategoryId;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesProvider = Provider.of<CategoriesProvider>(context);
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, MediaQuery.of(context).size.height * _slideAnimation.value),
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              leading: IconButton(
                onPressed: () {
                  _animationController.reverse().then((_) {
                    Navigator.pop(context);
                  });
                },
                icon: const Icon(Icons.close),
              ),
              title: Text(
                'Select Category',
                style: AppTypography.titleLarge.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              centerTitle: true,
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search categories...',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: AppTypography.bodyMedium,
                    onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (categoriesProvider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (categoriesProvider.error != null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading categories',
                                style: AppTypography.titleMedium.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                  onPressed: () {
                                    categoriesProvider.loadCategories(forceRefresh: true);
                                  },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }
                      final categories = categoriesProvider.categories;
                      if (categories.isEmpty) {
                        return Center(
                          child: Text(
                            'No categories available',
                            style: AppTypography.bodyLarge.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      final filtered = _search.isEmpty
                          ? categories
                          : categories.where((c) => c.name.toLowerCase().contains(_search)).toList();
                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            'No results found',
                            style: AppTypography.bodyLarge.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      final Map<String, List<Category>> grouped = {};
                      for (final c in filtered) {
                        grouped.putIfAbsent(c.categoryGroupName, () => []).add(c);
                      }
                      // Сортируем категории внутри каждой группы по rank (по возрастанию)
                      for (final group in grouped.values) {
                        group.sort((a, b) => a.rank.compareTo(b.rank));
                      }
                      final sortedGroups = grouped.entries.toList()
                        ..sort((a, b) => b.value.first.categoryGroupRank.compareTo(a.value.first.categoryGroupRank));
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: sortedGroups.length,
                        itemBuilder: (context, groupIdx) {
                          final groupName = sortedGroups[groupIdx].key;
                          final groupCats = sortedGroups[groupIdx].value;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                                child: Text(
                                  groupName,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final cat in groupCats)
                                    ChoiceChip(
                                      selected: cat.id == _selectedId,
                                      showCheckmark: false,
                                      onSelected: (selected) {
                                        setState(() => _selectedId = cat.id);
                                        if (selected) {
                                          _animationController.reverse().then((_) {
                                            Navigator.pop(context, cat);
                                          });
                                        }
                                      },
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          cat.id == _selectedId
                                              ? Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.onPrimary)
                                              : Icon(cat.iconData, size: 18, color: Theme.of(context).colorScheme.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            cat.name,
                                            style: AppTypography.bodyMedium.copyWith(
                                              color: cat.id == _selectedId
                                                  ? Theme.of(context).colorScheme.onPrimary
                                                  : Theme.of(context).colorScheme.onSurface,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      selectedColor: Theme.of(context).colorScheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                    ),
                                ],
                              ),
                              if (groupIdx < sortedGroups.length - 1)
                                const SizedBox(height: 16),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

IconData getCategoryIcon(String name) {
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