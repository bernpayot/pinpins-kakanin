import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BasketService {
  BasketService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _basketKey = 'shopify_guest_basket';
  static const _cartKey = 'shopify_cart_id';
  static const _attributesKey = 'shopify_basket_attributes';

  final FlutterSecureStorage _storage;

  Future<Map<String, int>> load() async {
    final value = await _storage.read(key: _basketKey);
    if (value == null) return {};

    try {
      final json = jsonDecode(value);
      if (json is! Map<String, dynamic>) throw const FormatException();

      return json.map((variantId, quantity) {
        if (quantity is! int || quantity < 1 || quantity > 99) {
          throw const FormatException();
        }
        return MapEntry(variantId, quantity);
      });
    } on FormatException {
      await _storage.delete(key: _basketKey);
      return {};
    }
  }

  Future<void> save(Map<String, int> basket) => basket.isEmpty
      ? _storage.delete(key: _basketKey)
      : _storage.write(key: _basketKey, value: jsonEncode(basket));

  Future<Map<String, Map<String, String>>> loadAttributes() async {
    final value = await _storage.read(key: _attributesKey);
    if (value == null) return {};
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      return json.map(
        (id, attributes) => MapEntry(
          id,
          (attributes as Map<String, dynamic>).cast<String, String>(),
        ),
      );
    } catch (_) {
      await _storage.delete(key: _attributesKey);
      return {};
    }
  }

  Future<void> saveAttributes(Map<String, Map<String, String>> attributes) =>
      attributes.isEmpty
      ? _storage.delete(key: _attributesKey)
      : _storage.write(key: _attributesKey, value: jsonEncode(attributes));

  Future<String?> loadCartId() => _storage.read(key: _cartKey);

  Future<void> saveCartId(String? cartId) => cartId == null
      ? _storage.delete(key: _cartKey)
      : _storage.write(key: _cartKey, value: cartId);
}
