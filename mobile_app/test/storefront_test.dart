import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/account_service.dart';
import 'package:mobile_app/auth_service.dart';
import 'package:mobile_app/basket_service.dart';
import 'package:mobile_app/checkout_service.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/product_service.dart';
import 'package:mobile_app/store_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('catalog model keeps every purchasable variant and its money', () {
    final product = Product.fromJson({
      'id': 'gid://shopify/Product/1',
      'title': 'Bibingka',
      'description': 'Rice cake',
      'featuredImage': {'url': 'https://example.com/bibingka.jpg'},
      'variants': {
        'nodes': [
          {
            'id': 'gid://shopify/ProductVariant/1',
            'title': 'Small',
            'selectedOptions': [
              {'name': 'Size', 'value': 'Small'},
            ],
            'availableForSale': true,
            'price': {'amount': '120.00', 'currencyCode': 'PHP'},
          },
          {
            'id': 'gid://shopify/ProductVariant/2',
            'title': 'Large',
            'selectedOptions': [
              {'name': 'Size', 'value': 'Large'},
            ],
            'availableForSale': false,
            'price': {'amount': '220.00', 'currencyCode': 'PHP'},
          },
        ],
      },
    });

    expect(product.variants, hasLength(2));
    expect(product.variants.first.id, 'gid://shopify/ProductVariant/1');
    expect(product.variants.first.label, 'Small');
    expect(product.variants.last.availableForSale, isFalse);
    expect(product.variants.last.price.formatted, 'PHP 220.00');
  });

  test('product details load its variants', () async {
    final product = await http.runWithClient(
      () => ProductService.getProduct('bibingka'),
      () => MockClient((request) async {
        expect(request.url.queryParameters['after'], isNull);
        return http.Response(jsonEncode(_productDetailsJson), 200);
      }),
    );

    expect(product.imageUrls, ['https://example.com/bibingka.jpg']);
    expect(product.variants.single.id, 'gid://shopify/ProductVariant/1');
  });

  test('basket persists only variant IDs and quantities', () async {
    final basket = BasketService();

    await basket.save({
      'gid://shopify/ProductVariant/1': 2,
      'gid://shopify/ProductVariant/2': 1,
    });

    await basket.saveCartId('gid://shopify/Cart/1?key=secret');

    expect(await basket.load(), {
      'gid://shopify/ProductVariant/1': 2,
      'gid://shopify/ProductVariant/2': 1,
    });
    expect(await basket.loadCartId(), 'gid://shopify/Cart/1?key=secret');
  });

  test('Shopify cart sync removes, updates, and adds lines', () async {
    var request = 0;
    final cart = await http.runWithClient(
      () => ProductService.syncCart({
        'gid://shopify/ProductVariant/1': 2,
        'gid://shopify/ProductVariant/3': 1,
      }, cartId: 'gid://shopify/Cart/1?key=secret'),
      () => MockClient((httpRequest) async {
        request++;
        final body = jsonDecode(httpRequest.body) as Map<String, dynamic>;
        if (request == 1) {
          expect(httpRequest.url.path, endsWith('/cart/read'));
          return http.Response(
            jsonEncode(_cartJson([_cartLine(1), _cartLine(2)])),
            200,
          );
        }
        if (request == 2) {
          expect(body, containsPair('lineId', 'gid://shopify/CartLine/2'));
          expect(body, containsPair('quantity', 0));
          return http.Response(jsonEncode(_cartJson([_cartLine(1)])), 200);
        }
        if (request == 3) {
          expect(body, containsPair('lineId', 'gid://shopify/CartLine/1'));
          expect(body, containsPair('quantity', 2));
          return http.Response(
            jsonEncode(_cartJson([_cartLine(1, quantity: 2)])),
            200,
          );
        }
        expect(
          body,
          containsPair('variantId', 'gid://shopify/ProductVariant/3'),
        );
        return http.Response(
          jsonEncode(_cartJson([_cartLine(1, quantity: 2), _cartLine(3)])),
          200,
        );
      }),
    );

    expect(request, 4);
    expect(cart.lines.map((line) => line.variantId), [
      'gid://shopify/ProductVariant/1',
      'gid://shopify/ProductVariant/3',
    ]);
    expect(cart.subtotal.formatted, 'PHP 240.00');
  });

  test(
    'credential rotation does not restore the previous client session',
    () async {
      const storage = FlutterSecureStorage();
      final oldSession = AuthSession(
        accessToken: 'old-access-token',
        idToken: 'old-id-token',
        expiresAt: DateTime.utc(2100),
      );
      await storage.write(
        key: 'shopify_customer_session',
        value: oldSession.toJson(),
      );
      await storage.write(
        key: 'shopify_customer_session_${ShopifyAuthConfig.clientId}',
        value: _session.toJson(),
      );

      final restored = await ShopifyAuthService(
        storage: storage,
      ).restoreSession();

      expect(restored?.accessToken, _session.accessToken);
    },
  );

  test('account rejection renews once with the rejected token', () async {
    final auth = _FakeAuth(session: _session);
    var requests = 0;

    final customer = await http.runWithClient(
      () => AccountService(auth).currentCustomer(),
      () => MockClient((request) async {
        if (request.url.path.endsWith('/.well-known/customer-account-api')) {
          return _customerDiscovery();
        }
        requests++;
        if (request.headers['Authorization'] == 'renewed-token') {
          return _customerResponse({'customer': _customerJson});
        }
        return http.Response('', 401);
      }),
    );

    expect(customer.displayName, 'Sally Shopper');
    expect(requests, 2);
    expect(auth.renewedTokens, ['access-token']);
  });

  test('concurrent token requests share one OAuth login', () async {
    final auth = _LoginAuth();

    final tokens = await Future.wait([
      auth.accessToken(),
      auth.accessToken(),
      auth.accessToken(),
    ]);

    expect(tokens, everyElement('access-token'));
    expect(auth.loginCalls, 1);
  });

  test('account loads orders and addresses and updates the profile', () async {
    final auth = _FakeAuth();

    await http.runWithClient(
      () async {
        final service = AccountService(auth);
        final orders = await service.orders();
        final addresses = await service.addresses();
        await service.setDefaultAddress(addresses.items.last);
        final customer = await service.updateProfile(
          firstName: 'Maria',
          lastName: 'Santos',
        );

        expect(orders.items.single.name, '#1001');
        expect(orders.items.single.lines.single.name, 'Bibingka');
        expect(addresses.items.first.isDefault, isTrue);
        expect(addresses.items.first.formatted, ['123 Rice Street', 'Manila']);
        expect(customer.displayName, 'Maria Santos');
      },
      () => MockClient((request) async {
        if (request.url.path.endsWith('/.well-known/customer-account-api')) {
          return _customerDiscovery();
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final query = body['query'] as String;
        if (query.contains('CustomerOrders')) {
          return _customerResponse({
            'customer': {
              'orders': {
                'nodes': [_orderJson],
                'pageInfo': {'hasNextPage': false, 'endCursor': null},
              },
            },
          });
        }
        if (query.contains('CustomerAddresses')) {
          return _customerResponse({'customer': _addressesJson});
        }
        if (query.contains('UpdateAddress')) {
          expect(body['variables'], {
            'addressId': 'gid://shopify/CustomerAddress/2',
            'address': {
              'firstName': 'Sally',
              'lastName': 'Shopper',
              'address1': '456 Cake Street',
              'city': 'Imus',
              'territoryCode': 'PH',
              'zip': '4103',
            },
          });
          return _customerResponse({
            'customerAddressUpdate': {'userErrors': []},
          });
        }
        if (query.contains('UpdateCustomer')) {
          expect(body['variables'], {
            'input': {'firstName': 'Maria', 'lastName': 'Santos'},
          });
          return _customerResponse({
            'customerUpdate': {
              'customer': {
                'firstName': 'Maria',
                'lastName': 'Santos',
                'emailAddress': {'emailAddress': 'sally@example.com'},
              },
              'userErrors': [],
            },
          });
        }
        throw StateError('Unexpected customer query: $query');
      }),
    );
  });

  test('catalog error includes the backend message', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'message': 'Shopify Storefront API is not configured.'}),
        500,
      ),
    );

    await expectLater(
      http.runWithClient(ProductService.getProductBatch, () => client),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Shopify Storefront API is not configured.'),
        ),
      ),
    );
  });

  test('cart submits customer token, IDs, and quantities', () async {
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer customer-token');
      expect(jsonDecode(request.body), {
        'lines': [
          {'variantId': 'gid://shopify/ProductVariant/1', 'quantity': 2},
        ],
      });

      return http.Response(
        jsonEncode({
          'errors': [
            {'message': 'The merchandise is unavailable.'},
          ],
        }),
        422,
      );
    });

    await expectLater(
      http.runWithClient(
        () => ProductService.createCart({
          'gid://shopify/ProductVariant/1': 2,
        }, customerAccessToken: 'customer-token'),
        () => client,
      ),
      throwsA(
        isA<CheckoutException>().having(
          (error) => error.message,
          'message',
          'The merchandise is unavailable.',
        ),
      ),
    );
  });

  test('checkout preload sends the URL to the native SDK', () async {
    MethodCall? call;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.pinpinskakanin/checkout'),
          (value) async {
            call = value;
            return null;
          },
        );

    await CheckoutKit.preload(Uri.parse('https://shop.example/checkouts/abc'));

    expect(call?.method, 'preload');
    expect(call?.arguments, {
      'checkoutUrl': 'https://shop.example/checkouts/abc',
    });
  });

  testWidgets('checkout launch failure keeps the basket', (tester) async {
    final basket = BasketService();
    const lines = {'gid://shopify/ProductVariant/1': 2};
    await basket.save(lines);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.pinpinskakanin/checkout'),
          (call) async => call.method == 'present'
              ? throw PlatformException(
                  code: 'checkout_failed',
                  message: 'Could not open checkout',
                )
              : null,
        );

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: BasketPage(
              products: const [],
              initialBasket: lines,
              basketService: basket,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Checkout'));
        await tester.pumpAndSettle();
      },
      () => _storeClient((request) {
        if (request.url.path.endsWith('/shopify/cart')) {
          return http.Response(
            jsonEncode(_cartJson([_cartLine(1, quantity: 2)])),
            201,
          );
        }
        return null;
      }),
    );

    expect(find.text('Could not open checkout'), findsOneWidget);
    expect(await basket.load(), lines);
  });

  testWidgets('completed checkout clears the basket', (tester) async {
    final basket = BasketService();
    const lines = {'gid://shopify/ProductVariant/1': 2};
    await basket.save(lines);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.pinpinskakanin/checkout'),
          (call) async => call.method == 'present' ? 'completed' : null,
        );

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: BasketPage(
              products: const [],
              initialBasket: lines,
              basketService: basket,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Checkout'));
        await tester.pumpAndSettle();
      },
      () => _storeClient((request) {
        if (request.url.path.endsWith('/shopify/cart')) {
          return http.Response(
            jsonEncode(_cartJson([_cartLine(1, quantity: 2)])),
            201,
          );
        }
        return null;
      }),
    );

    expect(find.text('Your basket is empty'), findsOneWidget);
    expect(await basket.load(), isEmpty);
    expect(await basket.loadCartId(), isNull);
  });

  testWidgets('fresh installation opens products without requesting account', (
    tester,
  ) async {
    var accountRequests = 0;

    await http.runWithClient(
      () async {
        await tester.pumpWidget(MaterialApp(home: AuthGate(auth: _FakeAuth())));
        await tester.pumpAndSettle();
      },
      () => _storeClient((request) {
        if (request.url.host == 'accounts.example') accountRequests++;
        return null;
      }),
    );

    expect(find.text('No products found'), findsOneWidget);
    expect(find.byTooltip('Account'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    expect(accountRequests, 0);
  });

  testWidgets('one failed account section does not hide the others', (
    tester,
  ) async {
    final auth = _FakeAuth(session: _session);

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AccountPage(auth: auth, signOut: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
      },
      () => _storeClient((request) {
        if (request.url.host == 'accounts.example' &&
            (jsonDecode(request.body) as Map<String, dynamic>)['query']
                .toString()
                .contains('CustomerOrders')) {
          return http.Response('', 401);
        }
        return null;
      }),
    );

    expect(find.textContaining('Shopify rejected'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Sally Shopper'), findsOneWidget);
    expect(find.textContaining('123 Rice Street'), findsOneWidget);
    expect(auth.session, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account page paginates orders and shows saved addresses', (
    tester,
  ) async {
    final auth = _FakeAuth(session: _session);
    var orderRequests = 0;

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AccountPage(auth: auth, signOut: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Load more orders'));
        await tester.pumpAndSettle();
      },
      () => _storeClient((request) {
        if (request.url.host != 'accounts.example') return null;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (!(body['query'] as String).contains('CustomerOrders')) return null;

        orderRequests++;
        final isNextPage =
            (body['variables'] as Map<String, dynamic>)['after'] ==
            'orders-page-2';
        return _customerResponse({
          'customer': {
            'orders': {
              'nodes': [
                {..._orderJson, 'name': isNextPage ? '#1002' : '#1001'},
              ],
              'pageInfo': {
                'hasNextPage': !isNextPage,
                'endCursor': isNextPage ? null : 'orders-page-2',
              },
            },
          },
        });
      }),
    );

    expect(find.text('#1001'), findsOneWidget);
    expect(find.text('#1002'), findsOneWidget);
    expect(find.text('2× Bibingka'), findsWidgets);
    expect(orderRequests, 2);
    expect(find.textContaining('123 Rice Street'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Make default'), findsOneWidget);
    expect(find.byTooltip('Edit profile'), findsOneWidget);
  });

  testWidgets('promotion opens when the app starts', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Order From The Catalog'), findsOneWidget);
  });

  testWidgets('store shell has no top bar and a bottom menu', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: AuthGate(auth: _FakeAuth())));
      await tester.pumpAndSettle();
    }, _storeClient);

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byTooltip('Account'), findsOneWidget);
    expect(find.byTooltip('Basket'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    expect(find.byTooltip('Reload'), findsNothing);
  });

  testWidgets('catalog shows products in a 2 x 2 grid on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Map<String, dynamic> product(String name) => {
      ..._productDetailsJson,
      'handle': name.toLowerCase(),
      'title': name,
      'description':
          'A long description of this kakanin that should wrap and be cut off neatly on the card.',
      'images': {'nodes': []},
      'variants': {
        'nodes': [
          for (final (i, size) in [
            'Tub',
            'X-Small',
            'Small',
            'Medium',
            'Large',
          ].indexed)
            {
              'id': 'gid://shopify/ProductVariant/$name$i',
              'title': size,
              'selectedOptions': [
                {'name': 'Size', 'value': size},
              ],
              'availableForSale': true,
              'price': {'amount': '${1200 + i}.5', 'currencyCode': 'PHP'},
            },
        ],
      },
    };
    await http.runWithClient(
      () async {
        await tester.pumpWidget(MaterialApp(home: AuthGate(auth: _FakeAuth())));
        await tester.pumpAndSettle();
      },
      () => _storeClient((request) {
        if (!request.url.path.endsWith('/shopify/products')) return null;
        return http.Response(
          jsonEncode({
            'nodes': [
              for (final name in ['Sapin-Sapin', 'Puto', 'Kutsinta', 'Maha'])
                product(name),
            ],
            'pageInfo': {'hasNextPage': false, 'endCursor': null},
          }),
          200,
        );
      }),
    );

    expect(tester.takeException(), isNull);
    final first = tester.getTopLeft(find.text('Sapin-Sapin'));
    final second = tester.getTopLeft(find.text('Puto'));
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
    expect(find.text('PHP 1200.50'), findsWidgets);
  });

  testWidgets('help tab has refund policy and a robot-guarded report form', (
    tester,
  ) async {
    final opened = <Uri>[];
    openLink = (uri) async {
      opened.add(uri);
      return true;
    };
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: AuthGate(auth: _FakeAuth())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Help'));
      await tester.pumpAndSettle();
    }, _storeClient);

    final helpList = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Cancellation and refund policy'),
      200,
      scrollable: helpList,
    );
    await tester.scrollUntilVisible(
      find.text('Order status updates'),
      200,
      scrollable: helpList,
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Your name'),
      200,
      scrollable: helpList,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your name'),
      'Ana',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your message'),
      'Hello',
    );
    await tester.ensureVisible(find.text('Send inquiry'));
    await tester.tap(find.text('Send inquiry'));
    await tester.pump();
    expect(find.textContaining('not a robot'), findsWidgets);
    expect(opened, isEmpty);

    ContactFormState.minimumFillTime = Duration.zero;
    addTearDown(
      () => ContactFormState.minimumFillTime = const Duration(seconds: 3),
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Send inquiry'));
    await tester.pump();
    expect(opened.single.scheme, 'sms');
    expect(opened.single.queryParameters['body'], contains('Hello'));
  });

  testWidgets('cancelling login leaves the store accessible', (tester) async {
    final auth = _FakeAuth(
      loginError: FlutterAppAuthUserCancelledException(
        code: 'cancelled',
        platformErrorDetails: FlutterAppAuthPlatformErrorDetails(),
      ),
    );

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: AuthGate(auth: auth)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
    }, _storeClient);

    expect(find.text('No products found'), findsOneWidget);
    expect(find.byTooltip('Account'), findsOneWidget);
  });

  testWidgets('signing out leaves the store accessible', (tester) async {
    final auth = _FakeAuth(session: _session);
    final basket = BasketService();
    await basket.saveCartId('gid://shopify/Cart/1?key=secret');

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(auth: auth, basket: basket),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
    }, _storeClient);

    expect(auth.logoutCalls, 1);
    expect(await basket.loadCartId(), isNull);
    expect(find.text('No products found'), findsOneWidget);
    expect(find.byTooltip('Account'), findsOneWidget);
  });
}

MockClient _storeClient([
  http.Response? Function(http.Request request)? handle,
]) => MockClient((request) async {
  final response = handle?.call(request);
  if (response != null) return response;

  if (request.url.path.endsWith('/shopify/products')) {
    return http.Response(
      jsonEncode({
        'nodes': [],
        'pageInfo': {'hasNextPage': false, 'endCursor': null},
      }),
      200,
    );
  }
  if (request.url.path.endsWith('/shopify/collections')) {
    return http.Response('[]', 200);
  }
  if (request.url.path.endsWith('/.well-known/customer-account-api')) {
    return _customerDiscovery();
  }

  final body = jsonDecode(request.body) as Map<String, dynamic>;
  final query = body['query'] as String;
  if (query.contains('CurrentCustomer')) {
    return _customerResponse({'customer': _customerJson});
  }
  if (query.contains('CustomerOrders')) {
    return _customerResponse({
      'customer': {
        'orders': {
          'nodes': [],
          'pageInfo': {'hasNextPage': false, 'endCursor': null},
        },
      },
    });
  }
  if (query.contains('CustomerAddresses')) {
    return _customerResponse({'customer': _addressesJson});
  }
  throw StateError('Unexpected request: ${request.url}');
});

http.Response _customerDiscovery() => http.Response(
  jsonEncode({
    'graphql_api': 'https://accounts.example/customer/api/2026-07/graphql',
  }),
  200,
);

http.Response _customerResponse(Map<String, dynamic> data) =>
    http.Response(jsonEncode({'data': data}), 200);

final _session = AuthSession(
  accessToken: 'access-token',
  idToken: 'id-token',
  expiresAt: DateTime.utc(2100),
);

const Map<String, dynamic> _productDetailsJson = {
  'handle': 'bibingka',
  'title': 'Bibingka',
  'description': 'Rice cake',
  'images': {
    'nodes': [
      {'url': 'https://example.com/bibingka.jpg'},
    ],
  },
  'variants': {
    'nodes': [
      {
        'id': 'gid://shopify/ProductVariant/1',
        'title': 'Size 1',
        'selectedOptions': [],
        'availableForSale': true,
        'price': {'amount': '120.00', 'currencyCode': 'PHP'},
      },
    ],
  },
};

Map<String, dynamic> _cartLine(int id, {int quantity = 1}) => {
  'id': 'gid://shopify/CartLine/$id',
  'quantity': quantity,
  'merchandise': {
    'id': 'gid://shopify/ProductVariant/$id',
    'title': 'Size $id',
    'availableForSale': true,
    'price': {'amount': '120.00', 'currencyCode': 'PHP'},
    'product': {'title': 'Bibingka $id'},
  },
};

Map<String, dynamic> _cartJson(List<Map<String, dynamic>> lines) => {
  'id': 'gid://shopify/Cart/1?key=secret',
  'checkoutUrl': 'https://shop.example/checkouts/abc',
  'cost': {
    'subtotalAmount': {'amount': '240.00', 'currencyCode': 'PHP'},
  },
  'lines': {'nodes': lines},
};

const _customerJson = {
  'firstName': 'Sally',
  'lastName': 'Shopper',
  'emailAddress': {'emailAddress': 'sally@example.com'},
};

const _orderJson = {
  'name': '#1001',
  'processedAt': '2026-09-08T00:00:00Z',
  'financialStatus': 'PAID',
  'fulfillmentStatus': 'FULFILLED',
  'totalPrice': {'amount': '240.00', 'currencyCode': 'PHP'},
  'lineItems': {
    'nodes': [
      {'name': 'Bibingka', 'quantity': 2},
    ],
  },
};

const _addressesJson = {
  'defaultAddress': {'id': 'gid://shopify/CustomerAddress/1'},
  'addresses': {
    'nodes': [
      {
        'id': 'gid://shopify/CustomerAddress/1',
        'formatted': ['123 Rice Street', 'Manila'],
        'firstName': 'Sally',
        'lastName': 'Shopper',
        'address1': '123 Rice Street',
        'city': 'Manila',
        'territoryCode': 'PH',
        'zip': '1000',
      },
      {
        'id': 'gid://shopify/CustomerAddress/2',
        'formatted': ['456 Cake Street', 'Imus'],
        'firstName': 'Sally',
        'lastName': 'Shopper',
        'address1': '456 Cake Street',
        'city': 'Imus',
        'territoryCode': 'PH',
        'zip': '4103',
      },
    ],
    'pageInfo': {'hasNextPage': false, 'endCursor': null},
  },
};

class _LoginAuth extends ShopifyAuthService {
  int loginCalls = 0;

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> login({bool silent = false}) async {
    loginCalls++;
    await Future<void>.delayed(Duration.zero);
    return _session;
  }
}

class _FakeAuth extends ShopifyAuthService {
  _FakeAuth({this.session, this.loginError});

  AuthSession? session;
  final Object? loginError;
  int logoutCalls = 0;
  int accessTokenCalls = 0;
  final renewedTokens = <String>[];

  @override
  Future<String> accessToken() async {
    accessTokenCalls++;
    return 'access-token';
  }

  @override
  Future<String> renewAccessToken(String rejectedToken) async {
    renewedTokens.add(rejectedToken);
    return 'renewed-token';
  }

  @override
  Future<AuthSession?> restoreSession() async => session;

  @override
  Future<AuthSession> login({bool silent = false}) async {
    if (loginError != null) throw loginError!;
    return session = _session;
  }

  @override
  Future<void> clearSession() async => session = null;

  @override
  Future<void> logout() async {
    logoutCalls++;
    session = null;
  }
}
