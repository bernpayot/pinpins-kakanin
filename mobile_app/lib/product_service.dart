import 'dart:convert';

import 'package:http/http.dart' as http;

class Money {
  const Money({required this.amount, required this.currencyCode});

  final String amount;
  final String currencyCode;

  /// Always two decimal places, e.g. "PHP 350.00".
  String get formatted {
    final value = double.tryParse(amount);
    return '$currencyCode ${value == null ? amount : value.toStringAsFixed(2)}';
  }

  factory Money.fromJson(Map<String, dynamic> json) => Money(
    amount: json['amount'] as String,
    currencyCode: json['currencyCode'] as String,
  );
}

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.title,
    required this.options,
    required this.availableForSale,
    required this.price,
    this.imageUrl,
  });

  final String id;
  final String title;
  final List<String> options;
  final bool availableForSale;
  final Money price;
  final String? imageUrl;

  String get label => options.isEmpty ? title : options.join(' / ');

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Default',
    options: (json['selectedOptions'] as List? ?? [])
        .map((option) => (option as Map<String, dynamic>)['value'] as String)
        .toList(),
    availableForSale: json['availableForSale'] as bool? ?? false,
    price: Money.fromJson(json['price'] as Map<String, dynamic>),
    imageUrl: (json['image'] as Map<String, dynamic>?)?['url'] as String?,
  );
}

class Product {
  const Product({
    required this.handle,
    required this.title,
    required this.description,
    required this.imageUrls,
    required this.variants,
  });

  final String handle;
  final String title;
  final String description;
  final List<String> imageUrls;
  final List<ProductVariant> variants;

  String? get imageUrl => imageUrls.firstOrNull;

  factory Product.fromJson(Map<String, dynamic> json) {
    final variants = json['variants'] as Map<String, dynamic>?;
    final image = json['featuredImage'] as Map<String, dynamic>?;
    final images = json['images'] as Map<String, dynamic>?;

    return Product(
      handle: json['handle'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled product',
      description: json['description'] as String? ?? '',
      imageUrls: images == null
          ? [if (image?['url'] case final String url) url]
          : (images['nodes'] as List? ?? [])
                .map((item) => (item as Map<String, dynamic>)['url'] as String)
                .toList(),
      variants: (variants?['nodes'] as List? ?? [])
          .map(
            (variant) =>
                ProductVariant.fromJson(variant as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class ProductBatch {
  const ProductBatch({
    required this.products,
    required this.hasNextPage,
    required this.endCursor,
  });

  final List<Product> products;
  final bool hasNextPage;
  final String? endCursor;

  factory ProductBatch.fromJson(Map<String, dynamic> json) {
    final pageInfo = json['pageInfo'] as Map<String, dynamic>? ?? {};
    return ProductBatch(
      products: (json['nodes'] as List? ?? [])
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList(),
      hasNextPage: pageInfo['hasNextPage'] as bool? ?? false,
      endCursor: pageInfo['endCursor'] as String?,
    );
  }
}

class ProductCollection {
  const ProductCollection({required this.handle, required this.title});

  final String handle;
  final String title;

  factory ProductCollection.fromJson(Map<String, dynamic> json) =>
      ProductCollection(
        handle: json['handle'] as String,
        title: json['title'] as String,
      );
}

class ShopifyCartLine {
  const ShopifyCartLine({
    required this.id,
    required this.variantId,
    required this.quantity,
    required this.productTitle,
    required this.variantTitle,
    required this.availableForSale,
    required this.price,
    required this.attributes,
    this.imageUrl,
  });

  final String id;
  final String variantId;
  final int quantity;
  final String productTitle;
  final String variantTitle;
  final bool availableForSale;
  final Money price;
  final Map<String, String> attributes;
  final String? imageUrl;

  factory ShopifyCartLine.fromJson(Map<String, dynamic> json) {
    final merchandise = json['merchandise'] as Map<String, dynamic>;
    final product = merchandise['product'] as Map<String, dynamic>;
    return ShopifyCartLine(
      id: json['id'] as String,
      variantId: merchandise['id'] as String,
      quantity: json['quantity'] as int,
      productTitle: product['title'] as String,
      variantTitle: merchandise['title'] as String? ?? 'Default',
      availableForSale: merchandise['availableForSale'] as bool? ?? false,
      price: Money.fromJson(merchandise['price'] as Map<String, dynamic>),
      attributes: {
        for (final attribute in json['attributes'] as List? ?? const [])
          (attribute as Map<String, dynamic>)['key'] as String:
              attribute['value'] as String,
      },
      imageUrl:
          (merchandise['image'] as Map<String, dynamic>?)?['url'] as String? ??
          (product['featuredImage'] as Map<String, dynamic>?)?['url']
              as String?,
    );
  }
}

class ShopifyCart {
  const ShopifyCart({
    required this.id,
    required this.checkoutUrl,
    required this.lines,
    required this.subtotal,
    required this.note,
  });

  final String id;
  final Uri checkoutUrl;
  final List<ShopifyCartLine> lines;
  final Money subtotal;
  final String note;

  factory ShopifyCart.fromJson(Map<String, dynamic> json) {
    final checkoutUrl = Uri.parse(json['checkoutUrl'] as String);
    if (checkoutUrl.scheme != 'https') {
      throw const FormatException('Invalid checkout URL');
    }
    final cost = json['cost'] as Map<String, dynamic>;
    final lines = json['lines'] as Map<String, dynamic>;
    return ShopifyCart(
      id: json['id'] as String,
      checkoutUrl: checkoutUrl,
      lines: (lines['nodes'] as List? ?? [])
          .map((line) => ShopifyCartLine.fromJson(line as Map<String, dynamic>))
          .toList(),
      subtotal: Money.fromJson(cost['subtotalAmount'] as Map<String, dynamic>),
      note: json['note'] as String? ?? '',
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

  static Future<ProductBatch> getProductBatch({
    String? search,
    String? collection,
    String? after,
  }) async {
    final uri = Uri.parse('$baseUrl/shopify/products').replace(
      queryParameters: {
        if (search?.isNotEmpty == true) 'search': search,
        if (collection?.isNotEmpty == true) 'collection': collection,
        'after': ?after,
      },
    );
    final response = await _get(uri);
    _expect(response, 200, 'retrieve products');
    return ProductBatch.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<List<ProductCollection>> getCollections() async {
    final response = await _get(Uri.parse('$baseUrl/shopify/collections'));
    _expect(response, 200, 'retrieve collections');
    return (jsonDecode(response.body) as List)
        .map((item) => ProductCollection.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<Product> getProduct(String handle) async {
    final response = await _get(Uri.parse('$baseUrl/shopify/products/$handle'));
    _expect(response, 200, 'retrieve product');
    return Product.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<ShopifyCart> syncCart(
    Map<String, int> basket, {
    Map<String, Map<String, String>> attributes = const {},
    String? cartId,
    String? customerAccessToken,
  }) async {
    if (cartId == null) {
      return createCart(
        basket,
        attributes: attributes,
        customerAccessToken: customerAccessToken,
      );
    }

    final existing = await getCart(
      cartId,
      customerAccessToken: customerAccessToken,
    );
    if (existing == null) {
      return createCart(
        basket,
        attributes: attributes,
        customerAccessToken: customerAccessToken,
      );
    }

    var cart = existing;
    for (final line in [...cart.lines]) {
      if (!basket.containsKey(line.variantId)) {
        cart = await _changeCart(cart.id, quantity: 0, lineId: line.id);
      }
    }
    for (final entry in basket.entries) {
      final line = cart.lines
          .where((line) => line.variantId == entry.key)
          .firstOrNull;
      if (line == null) {
        cart = await _changeCart(
          cart.id,
          quantity: entry.value,
          variantId: entry.key,
          attributes: attributes[entry.key],
        );
      } else if (line.quantity != entry.value ||
          !_sameAttributes(
            line.attributes,
            attributes[entry.key] ?? const {},
          )) {
        cart = await _changeCart(
          cart.id,
          quantity: entry.value,
          lineId: line.id,
          attributes: attributes[entry.key],
        );
      }
    }
    return cart;
  }

  static Future<ShopifyCart> createCart(
    Map<String, int> basket, {
    Map<String, Map<String, String>> attributes = const {},
    String? customerAccessToken,
  }) async {
    final response = await _post(Uri.parse('$baseUrl/shopify/cart'), {
      'lines': basket.entries
          .map(
            (line) => {
              'variantId': line.key,
              'quantity': line.value,
              if (attributes[line.key]?.isNotEmpty == true)
                'attributes': _attributeList(attributes[line.key]!),
            },
          )
          .toList(),
    }, customerAccessToken: customerAccessToken);
    _expect(response, 201, 'create cart');
    return ShopifyCart.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<ShopifyCart?> getCart(
    String cartId, {
    String? customerAccessToken,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/shopify/cart/read'),
      {'id': cartId},
      customerAccessToken: customerAccessToken,
    );
    if (response.statusCode == 404) return null;
    _expect(response, 200, 'retrieve cart');
    return ShopifyCart.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<ShopifyCart> updateCartNote(String cartId, String note) async {
    final response = await _post(Uri.parse('$baseUrl/shopify/cart/note'), {
      'cartId': cartId,
      'note': note.trim(),
    });
    _expect(response, 200, 'save order note');
    return ShopifyCart.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static Future<ShopifyCart> _changeCart(
    String cartId, {
    required int quantity,
    String? lineId,
    String? variantId,
    Map<String, String>? attributes,
  }) async {
    final response = await _post(Uri.parse('$baseUrl/shopify/cart/change'), {
      'cartId': cartId,
      'quantity': quantity,
      'lineId': ?lineId,
      'variantId': ?variantId,
      if (attributes != null) 'attributes': _attributeList(attributes),
    });
    _expect(response, 200, 'update cart');
    return ShopifyCart.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  static List<Map<String, String>> _attributeList(Map<String, String> values) =>
      values.entries
          .where((entry) => entry.value.trim().isNotEmpty)
          .map((entry) => {'key': entry.key, 'value': entry.value.trim()})
          .toList();

  static bool _sameAttributes(
    Map<String, String> left,
    Map<String, String> right,
  ) =>
      left.length == right.length &&
      left.entries.every((entry) => right[entry.key] == entry.value);

  static Future<http.Response> _get(Uri uri) =>
      http.get(uri, headers: const {'Accept': 'application/json'});

  static Future<http.Response> _post(
    Uri uri,
    Map<String, dynamic> body, {
    String? customerAccessToken,
  }) {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (customerAccessToken != null)
        'Authorization': 'Bearer $customerAccessToken',
    };
    return http.post(uri, headers: headers, body: jsonEncode(body));
  }

  static void _expect(http.Response response, int status, String action) {
    if (response.statusCode == status) return;

    var message = 'Failed to $action (${response.statusCode})';
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final errors = data['errors'] as List?;
        message = errors?.isNotEmpty == true
            ? errors!
                  .map((error) => (error as Map<String, dynamic>)['message'])
                  .join('\n')
            : data['message'] as String? ?? message;
      }
    } catch (_) {
      // Keep the status-based fallback for non-JSON responses.
    }
    throw CheckoutException(message);
  }
}
