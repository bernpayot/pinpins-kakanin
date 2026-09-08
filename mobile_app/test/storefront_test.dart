import 'dart:convert';

import 'package:flutter/material.dart';
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

  test('basket persists only variant IDs and quantities', () async {
    final basket = BasketService();

    await basket.save({
      'gid://shopify/ProductVariant/1': 2,
      'gid://shopify/ProductVariant/2': 1,
    });

    expect(await basket.load(), {
      'gid://shopify/ProductVariant/1': 2,
      'gid://shopify/ProductVariant/2': 1,
    });
  });

  test('catalog error includes the backend message', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'message': 'Shopify Storefront API is not configured.'}),
        500,
      ),
    );

    await expectLater(
      ProductService.getProducts(client: client),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Shopify Storefront API is not configured.'),
        ),
      ),
    );
  });

  test(
    'checkout submits IDs and quantities and surfaces Shopify errors',
    () async {
      final client = MockClient((request) async {
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
        ProductService.createCheckout({
          'gid://shopify/ProductVariant/1': 2,
        }, client: client),
        throwsA(
          isA<CheckoutException>().having(
            (error) => error.message,
            'message',
            'The merchandise is unavailable.',
          ),
        ),
      );
    },
  );

  testWidgets('checkout launch failure keeps the basket', (tester) async {
    final basket = BasketService();
    const lines = {'gid://shopify/ProductVariant/1': 2};
    await basket.save(lines);

    await tester.pumpWidget(
      MaterialApp(
        home: BasketPage(
          products: const [],
          initialBasket: lines,
          basketService: basket,
          checkoutCreator: (submitted) async {
            expect(submitted, lines);
            return CheckoutResult(
              url: Uri.parse('https://shop.example/checkouts/abc'),
              total: null,
            );
          },
          checkoutPresenter: (_) async =>
              throw const CheckoutKitException('Could not open checkout'),
        ),
      ),
    );
    await tester.tap(find.text('Checkout'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open checkout'), findsOneWidget);
    expect(await basket.load(), lines);
  });

  testWidgets('completed checkout clears the basket', (tester) async {
    final basket = BasketService();
    const lines = {'gid://shopify/ProductVariant/1': 2};
    await basket.save(lines);

    await tester.pumpWidget(
      MaterialApp(
        home: BasketPage(
          products: const [],
          initialBasket: lines,
          basketService: basket,
          checkoutCreator: (_) async => CheckoutResult(
            url: Uri.parse('https://shop.example/checkouts/abc'),
            total: null,
          ),
          checkoutPresenter: (_) async => CheckoutStatus.completed,
        ),
      ),
    );
    await tester.tap(find.text('Checkout'));
    await tester.pumpAndSettle();

    expect(find.text('Your basket is empty'), findsOneWidget);
    expect(await basket.load(), isEmpty);
  });

  testWidgets('fresh installation opens products without requesting account', (
    tester,
  ) async {
    var accountRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          auth: _FakeAuth(),
          productsLoader: () async => [],
          customerLoader: () async {
            accountRequests++;
            return _customer;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No products found'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(accountRequests, 0);
  });

  testWidgets('failed reload is rendered without a setState exception', (
    tester,
  ) async {
    var requests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          auth: _FakeAuth(),
          productsLoader: () {
            requests++;
            return requests == 1
                ? Future.value([])
                : Future.error(Exception('catalog unavailable'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reload'));
    await tester.pumpAndSettle();

    expect(find.textContaining('catalog unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling login leaves the store accessible', (tester) async {
    final auth = _FakeAuth(
      loginError: FlutterAppAuthUserCancelledException(
        code: 'cancelled',
        platformErrorDetails: FlutterAppAuthPlatformErrorDetails(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(auth: auth, productsLoader: () async => []),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('No products found'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('signing out leaves the store accessible', (tester) async {
    final auth = _FakeAuth(session: _session);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          auth: auth,
          productsLoader: () async => [],
          customerLoader: () async => _customer,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
    expect(find.text('No products found'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}

final _session = AuthSession(
  accessToken: 'access-token',
  idToken: 'id-token',
  expiresAt: DateTime.utc(2100),
);

const _customer = CustomerAccount(
  firstName: 'Sally',
  lastName: 'Shopper',
  email: 'sally@example.com',
);

class _FakeAuth extends ShopifyAuthService {
  _FakeAuth({this.session, this.loginError});

  AuthSession? session;
  final Object? loginError;
  int logoutCalls = 0;

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
