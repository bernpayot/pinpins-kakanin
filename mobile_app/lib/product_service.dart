import 'dart:convert';

import 'package:http/http.dart' as http;

class Money {
  const Money({required this.amount, required this.currencyCode});

  final String amount;
  final String currencyCode;

  String get formatted => '$currencyCode $amount';

  factory Money.fromJson(Map<String, dynamic> json) => Money(
    amount: json['amount'] as String,
    currencyCode: json['currencyCode'] as String,
  );
}

class ProductOption {
  const ProductOption({required this.name, required this.value});

  final String name;
  final String value;

  factory ProductOption.fromJson(Map<String, dynamic> json) => ProductOption(
    name: json['name'] as String,
    value: json['value'] as String,
  );
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.title,
    required this.options,
    required this.availableForSale,
    required this.price,
  });

  final String id;
  final String title;
  final List<ProductOption> options;
  final bool availableForSale;
  final Money price;

  String get label => options.isEmpty
      ? title
      : options.map((option) => option.value).join(' / ');

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Default',
    options: (json['selectedOptions'] as List? ?? [])
        .map((option) => ProductOption.fromJson(option as Map<String, dynamic>))
        .toList(),
    availableForSale: json['availableForSale'] as bool? ?? false,
    price: Money.fromJson(json['price'] as Map<String, dynamic>),
  );
}

class Product {
  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.variants,
  });

  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final List<ProductVariant> variants;

  factory Product.fromJson(Map<String, dynamic> json) {
    final variants = json['variants'] as Map<String, dynamic>?;
    final image = json['featuredImage'] as Map<String, dynamic>?;

    return Product(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled product',
      description: json['description'] as String? ?? '',
      imageUrl: image?['url'] as String?,
      variants: (variants?['nodes'] as List? ?? [])
          .map(
            (variant) =>
                ProductVariant.fromJson(variant as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class CheckoutResult {
  const CheckoutResult({required this.url, required this.total});

  final Uri url;
  final Money? total;

  factory CheckoutResult.fromJson(Map<String, dynamic> json) {
    final cost = json['cost'] as Map<String, dynamic>?;
    final total = cost?['totalAmount'] as Map<String, dynamic>?;
    final url = Uri.parse(json['checkoutUrl'] as String);

    if (url.scheme != 'https') {
      throw const FormatException('Invalid checkout URL');
    }

    return CheckoutResult(
      url: url,
      total: total == null ? null : Money.fromJson(total),
    );
  }
}

class CheckoutException implements Exception {
  const CheckoutException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProductService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  static Future<List<Product>> getProducts({http.Client? client}) async {
    final response =
        await (client?.get(
              Uri.parse('$baseUrl/shopify/products'),
              headers: {'Accept': 'application/json'},
            ) ??
            http.get(
              Uri.parse('$baseUrl/shopify/products'),
              headers: {'Accept': 'application/json'},
            ));

    if (response.statusCode != 200) {
      var message = 'Failed to retrieve products (${response.statusCode})';
      try {
        final error = jsonDecode(response.body);
        if (error is Map<String, dynamic> && error['message'] is String) {
          message = error['message'] as String;
        }
      } catch (_) {
        // Keep the status-based fallback for non-JSON responses.
      }
      throw Exception(message);
    }

    final data = jsonDecode(response.body);
    if (data is! List) throw const FormatException('Invalid products response');

    return data
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<CheckoutResult> createCheckout(
    Map<String, int> basket, {
    http.Client? client,
  }) async {
    final uri = Uri.parse('$baseUrl/shopify/checkout');
    final body = jsonEncode({
      'lines': basket.entries
          .map((line) => {'variantId': line.key, 'quantity': line.value})
          .toList(),
    });
    final response =
        await (client?.post(
              uri,
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: body,
            ) ??
            http.post(
              uri,
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: body,
            ));
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final errors = data['errors'] as List?;
      final message = errors?.isNotEmpty == true
          ? errors!
                .map((error) => (error as Map<String, dynamic>)['message'])
                .join('\n')
          : data['message'] as String? ?? 'Checkout failed';
      throw CheckoutException(message);
    }

    return CheckoutResult.fromJson(data);
  }
}
