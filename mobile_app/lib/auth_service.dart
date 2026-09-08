import 'dart:convert';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ShopifyAuthConfig {
  static const clientId = String.fromEnvironment('SHOPIFY_CUSTOMER_CLIENT_ID');
  static const storefrontUrl = String.fromEnvironment('SHOPIFY_STOREFRONT_URL');
  static const redirectScheme = String.fromEnvironment(
    'SHOPIFY_REDIRECT_SCHEME',
    defaultValue: 'shop.configure-me.pinpinskakanin',
  );

  static String get discoveryUrl =>
      '${storefrontUrl.replaceAll(RegExp(r'/$'), '')}/.well-known/openid-configuration';
  static String get redirectUrl => '$redirectScheme://auth/callback';

  static void validate() {
    if (clientId.isEmpty || storefrontUrl.isEmpty) {
      throw StateError(
        'Set SHOPIFY_CUSTOMER_CLIENT_ID and SHOPIFY_STOREFRONT_URL with --dart-define.',
      );
    }
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.idToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String idToken;
  final DateTime expiresAt;

  bool isExpiring({DateTime? now}) => expiresAt.isBefore(
    (now ?? DateTime.now()).add(const Duration(seconds: 30)),
  );

  String toJson() => jsonEncode({
    'accessToken': accessToken,
    'idToken': idToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  });

  factory AuthSession.fromJson(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    return AuthSession(
      accessToken: json['accessToken'] as String,
      idToken: json['idToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}

class ShopifyAuthService {
  ShopifyAuthService({FlutterAppAuth? appAuth, FlutterSecureStorage? storage})
    : _appAuth = appAuth ?? FlutterAppAuth(),
      _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'shopify_customer_session';
  static const _scopes = ['openid', 'email', 'customer-account-api:full'];

  final FlutterAppAuth _appAuth;
  final FlutterSecureStorage _storage;

  Future<AuthSession?> restoreSession() async {
    final value = await _storage.read(key: _sessionKey);
    if (value == null) return null;

    try {
      final session = AuthSession.fromJson(value);
      if (!session.isExpiring()) return session;
    } on FormatException {
      // Invalid local data is treated as a signed-out session.
    }

    await clearSession();
    return null;
  }

  Future<AuthSession> login({bool silent = false}) async {
    ShopifyAuthConfig.validate();
    final response = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        ShopifyAuthConfig.clientId,
        ShopifyAuthConfig.redirectUrl,
        discoveryUrl: ShopifyAuthConfig.discoveryUrl,
        scopes: _scopes,
        promptValues: silent ? const ['none'] : null,
      ),
    );
    final accessToken = response.accessToken;
    final idToken = response.idToken;
    final expiresAt = response.accessTokenExpirationDateTime;

    if (accessToken == null || idToken == null || expiresAt == null) {
      throw StateError(
        'Shopify returned an incomplete authentication response.',
      );
    }

    final session = AuthSession(
      accessToken: accessToken,
      idToken: idToken,
      expiresAt: expiresAt,
    );
    await _storage.write(key: _sessionKey, value: session.toJson());
    return session;
  }

  Future<String> accessToken({bool renew = false}) async {
    final session = await restoreSession();
    if (!renew && session != null && !session.isExpiring()) {
      return session.accessToken;
    }

    try {
      return (await login(silent: true)).accessToken;
    } on FlutterAppAuthPlatformException catch (error) {
      if (error.platformErrorDetails.error != 'login_required') rethrow;
      return (await login()).accessToken;
    }
  }

  Future<void> clearSession() => _storage.delete(key: _sessionKey);

  Future<void> logout() async {
    final session = await restoreSession();

    try {
      if (session != null) {
        ShopifyAuthConfig.validate();
        await _appAuth.endSession(
          EndSessionRequest(
            idTokenHint: session.idToken,
            discoveryUrl: ShopifyAuthConfig.discoveryUrl,
          ),
        );
      }
    } finally {
      await clearSession();
    }
  }
}
