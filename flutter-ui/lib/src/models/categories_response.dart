import 'category.dart';

class CategoriesResponse {
  final List<Category> categories;
  final String? nextToken;

  CategoriesResponse({
    required this.categories,
    this.nextToken,
  });

  factory CategoriesResponse.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List? ?? [];
    final categories = items.map((item) => Category.fromJson(item)).toList();
    
    return CategoriesResponse(
      categories: categories,
      nextToken: json['nextToken'],
    );
  }
} 