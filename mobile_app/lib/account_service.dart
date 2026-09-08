import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class CustomerAccount {
  const CustomerAccount({
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  final String firstName;
  final String lastName;
  final String email;

  String get displayName =>
      [firstName, lastName].where((part) => part.isNotEmpty).join(' ');

  factory CustomerAccount.fromJson(Map<String, dynamic> json) {
    final emailAddress = json['emailAddress'] as Map<String, dynamic>?;
    return CustomerAccount(
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: emailAddress?['emailAddress'] as String? ?? '',
    );
  }
}

class AuthenticationExpiredException implements Exception {
  const AuthenticationExpiredException();
}

class AccountService {
  AccountService(this.auth);

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  final ShopifyAuthService auth;

  Future<CustomerAccount> currentCustomer({
    bool renewOnUnauthorized = true,
  }) async {
    var response = await _get(await auth.accessToken());

    if (response.statusCode == 401 && !renewOnUnauthorized) {
      throw const AuthenticationExpiredException();
    }
    if (response.statusCode == 401) {
      response = await _get(await auth.accessToken(renew: true));
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to retrieve account (${response.statusCode})');
    }

    return CustomerAccount.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<http.Response> _get(String accessToken) => http.get(
    Uri.parse('$baseUrl/account'),
    headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
  );
}
