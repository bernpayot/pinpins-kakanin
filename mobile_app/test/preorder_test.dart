import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/preorder.dart';
import 'package:mobile_app/product_service.dart';

void main() {
  test('pre-order dates enforce tomorrow and special-date notice', () {
    final now = DateTime(2026, 10, 27);

    expect(preorderDateError(DateTime(2026, 10, 27), now: now), isNotNull);
    expect(preorderDateError(DateTime(2026, 10, 28), now: now), isNull);
    expect(preorderDateError(DateTime(2026, 11, 1), now: now), isNotNull);
    expect(
      preorderDateError(DateTime(2026, 11, 1), now: DateTime(2026, 10, 25)),
      isNull,
    );
  });

  test('cart creation sends preferred date and special request', () async {
    await http.runWithClient(
      () => ProductService.createCart(
        {'gid://shopify/ProductVariant/1': 2},
        attributes: {
          'gid://shopify/ProductVariant/1': {
            'Preferred Date': '2026-10-28',
            'Special request': 'Less sweet',
          },
        },
      ),
      () => MockClient((request) async {
        final line = (jsonDecode(request.body)['lines'] as List).single;
        expect(line['attributes'], [
          {'key': 'Preferred Date', 'value': '2026-10-28'},
          {'key': 'Special request', 'value': 'Less sweet'},
        ]);
        return http.Response(jsonEncode(_cart), 201);
      }),
    );
  });
}

const _cart = {
  'id': 'gid://shopify/Cart/1?key=secret',
  'checkoutUrl': 'https://shop.example/checkouts/abc',
  'cost': {
    'subtotalAmount': {'amount': '240.00', 'currencyCode': 'PHP'},
  },
  'lines': {'nodes': []},
};
