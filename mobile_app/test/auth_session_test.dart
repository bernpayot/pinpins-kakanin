import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/auth_service.dart';

void main() {
  test('redirect scheme matches the registered mobile callback', () {
    expect(ShopifyAuthConfig.redirectScheme, 'shop.83065831663.pinpinskakanin');
  });

  test(
    'mobile logout uses the API endpoint and clears the session',
    () async {
      final session = AuthSession(
        accessToken: 'access-token',
        idToken: 'id-token',
        expiresAt: DateTime.utc(2100),
      );
      final key = 'shopify_customer_session_${ShopifyAuthConfig.clientId}';
      FlutterSecureStorage.setMockInitialValues({key: session.toJson()});
      var requests = 0;

      await http.runWithClient(
        ShopifyAuthService().logout,
        () => MockClient((request) async {
          requests++;
          if (request.url == Uri.parse(ShopifyAuthConfig.discoveryUrl)) {
            return http.Response(
              jsonEncode({
                'end_session_endpoint': 'https://accounts.example/logout',
              }),
              200,
            );
          }
          expect(
            request.url.origin + request.url.path,
            'https://accounts.example/logout',
          );
          expect(request.url.queryParameters['id_token_hint'], 'id-token');
          return http.Response('', 200);
        }),
      );

      expect(requests, 2);
      expect(await const FlutterSecureStorage().read(key: key), isNull);
    },
    skip: ShopifyAuthConfig.storefrontUrl.isEmpty
        ? 'SHOPIFY_STOREFRONT_URL is required'
        : false,
  );

  test('session expires within the renewal window', () {
    final session = AuthSession(
      accessToken: 'access-token',
      idToken: 'id-token',
      expiresAt: DateTime.utc(2026, 1, 1, 0, 0, 29),
    );

    expect(session.isExpiring(now: DateTime.utc(2026)), isTrue);
  });

  test('session JSON round trip preserves tokens and expiry', () {
    final session = AuthSession(
      accessToken: 'access-token',
      idToken: 'id-token',
      expiresAt: DateTime.utc(2026, 1, 1, 1),
    );

    final restored = AuthSession.fromJson(session.toJson());

    expect(restored.accessToken, 'access-token');
    expect(restored.idToken, 'id-token');
    expect(restored.expiresAt, DateTime.utc(2026, 1, 1, 1));
  });
}
