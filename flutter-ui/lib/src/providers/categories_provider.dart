import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import 'base_provider.dart';

class CategoriesProvider extends BaseProvider {
  CategoriesProvider();

  List<Category> _categories = [];
  static const Duration _cacheDuration = Duration(minutes: 360);

  List<Category> get categories => _categories;
  String? get error => errorMessage;

  Category? get defaultCategory {
    if (_categories.isEmpty) return null;
    return _categories.reduce((a, b) => a.rank < b.rank ? a : b);
  }

  Future<void> loadCategories({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        !shouldRefresh(_cacheDuration) &&
        _categories.isNotEmpty) {
      return;
    }

    await execute(() async {
      final response = await ApiService.getCategories();
      _categories = response.categories;
      debugPrint(
          '[CategoriesProvider]: Loaded ${_categories.length} categories');
    });
  }

  void clearData() {
    _categories = [];
    notifyListeners();
  }
}
