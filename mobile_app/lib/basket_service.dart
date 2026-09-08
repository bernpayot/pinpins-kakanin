import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BasketService {
  BasketService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _basketKey = 'shopify_guest_basket';

  final FlutterSecureStorage _storage;

  Future<Map<String, int>> load() async {
    final value = await _storage.read(key: _basketKey);
    if (value == null) return {};

    try {
      final json = jsonDecode(value);
      if (json is! Map<String, dynamic>) throw const FormatException();

      return json.map((variantId, quantity) {
        if (quantity is! int || quantity < 1 || quantity > 250) {
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
}
