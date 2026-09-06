import 'dart:convert';
import 'package:http/http.dart' as http;

class Product {
  const Product({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.price,
  });

  final String title;
  final String description;
  final String? imageUrl;
  final String? price;

  factory Product.fromJson(Map<String, dynamic> json) {
    final variants = json['variants']?['nodes'] as List? ?? [];
    final image = json['featuredImage'] as Map<String, dynamic>?;
    return Product(
      title: json['title'] as String? ?? 'Untitled product',
      description: json['description'] as String? ?? '',
      imageUrl: image?['url'] as String?,
      price: variants.isEmpty ? null : variants.first['price'] as String?,
    );
  }
}

class ProductService {
  static const String baseUrl =
  String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000/api',
  );
  static Future<List<Product>> getProducts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/shopify/products'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to retrieve products (${response.statusCode})');
    }

    final data = jsonDecode(response.body);
    if (data is! List) throw Exception('Invalid products response');
    return data
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
