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

class CustomerOrderLine {
  const CustomerOrderLine({required this.name, required this.quantity});

  final String name;
  final int quantity;

  factory CustomerOrderLine.fromJson(Map<String, dynamic> json) =>
      CustomerOrderLine(
        name: json['name'] as String,
        quantity: json['quantity'] as int,
      );
}

class CustomerOrder {
  const CustomerOrder({
    required this.name,
    required this.processedAt,
    required this.financialStatus,
    required this.fulfillmentStatus,
    required this.amount,
    required this.currencyCode,
    required this.lines,
  });

  final String name;
  final DateTime processedAt;
  final String financialStatus;
  final String fulfillmentStatus;
  final String amount;
  final String currencyCode;
  final List<CustomerOrderLine> lines;

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    final total = json['totalPrice'] as Map<String, dynamic>;
    final lineItems = json['lineItems'] as Map<String, dynamic>;
    return CustomerOrder(
      name: json['name'] as String,
      processedAt: DateTime.parse(json['processedAt'] as String),
      financialStatus: json['financialStatus'] as String? ?? '',
      fulfillmentStatus: json['fulfillmentStatus'] as String? ?? '',
      amount: total['amount'] as String,
      currencyCode: total['currencyCode'] as String,
      lines: (lineItems['nodes'] as List)
          .map(
            (line) => CustomerOrderLine.fromJson(line as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.formatted,
    required this.isDefault,
    required this.input,
  });

  final String id;
  final List<String> formatted;
  final bool isDefault;
  final Map<String, dynamic> input;

  factory CustomerAddress.fromJson(
    Map<String, dynamic> json, {
    required String? defaultAddressId,
  }) => CustomerAddress(
    id: json['id'] as String,
    formatted: (json['formatted'] as List).cast<String>(),
    isDefault: json['id'] == defaultAddressId,
    input: {
      for (final key in const [
        'firstName',
        'lastName',
        'company',
        'address1',
        'address2',
        'city',
        'zoneCode',
        'territoryCode',
        'zip',
        'phoneNumber',
      ])
        if (json[key] != null) key: json[key],
    },
  );
}

class AccountConnection<T> {
  const AccountConnection({
    required this.items,
    required this.hasNextPage,
    required this.endCursor,
  });

  final List<T> items;
  final bool hasNextPage;
  final String? endCursor;
}

class AuthenticationExpiredException implements Exception {
  const AuthenticationExpiredException();

  @override
  String toString() => 'Shopify rejected the customer session.';
}

class AccountService {
  AccountService(this.auth);

  static const _customerQuery = r'''
    query CurrentCustomer {
      customer {
        firstName
        lastName
        emailAddress { emailAddress }
      }
    }
  ''';
  static const _ordersQuery = r'''
    query CustomerOrders($after: String) {
      customer {
        orders(first: 20, after: $after, reverse: true) {
          nodes {
            name
            processedAt
            financialStatus
            fulfillmentStatus
            totalPrice { amount currencyCode }
            lineItems(first: 20) {
              nodes { name quantity }
            }
          }
          pageInfo { hasNextPage endCursor }
        }
      }
    }
  ''';
  static const _addressesQuery = r'''
    query CustomerAddresses($after: String) {
      customer {
        defaultAddress { id }
        addresses(first: 20, after: $after) {
          nodes {
            id
            formatted
            firstName
            lastName
            company
            address1
            address2
            city
            zoneCode
            territoryCode
            zip
            phoneNumber
          }
          pageInfo { hasNextPage endCursor }
        }
      }
    }
  ''';
  static const _updateAddressMutation = r'''
    mutation UpdateAddress(
      $addressId: ID!
      $address: CustomerAddressInput!
    ) {
      customerAddressUpdate(
        addressId: $addressId
        address: $address
        defaultAddress: true
      ) {
        userErrors { message }
      }
    }
  ''';
  static const _updateCustomerMutation = r'''
    mutation UpdateCustomer($input: CustomerUpdateInput!) {
      customerUpdate(input: $input) {
        customer {
          firstName
          lastName
          emailAddress { emailAddress }
        }
        userErrors { message }
      }
    }
  ''';

  final ShopifyAuthService auth;
  Future<Uri>? _endpoint;

  Future<CustomerAccount> currentCustomer() async {
    final data = await _graphql(_customerQuery);
    return CustomerAccount.fromJson(data['customer'] as Map<String, dynamic>);
  }

  Future<AccountConnection<CustomerOrder>> orders({String? after}) async {
    final data = await _graphql(_ordersQuery, {'after': after});
    final orders =
        (data['customer'] as Map<String, dynamic>)['orders']
            as Map<String, dynamic>;
    final pageInfo = orders['pageInfo'] as Map<String, dynamic>;
    return AccountConnection(
      items: (orders['nodes'] as List)
          .map((order) => CustomerOrder.fromJson(order as Map<String, dynamic>))
          .toList(),
      hasNextPage: pageInfo['hasNextPage'] as bool,
      endCursor: pageInfo['endCursor'] as String?,
    );
  }

  Future<AccountConnection<CustomerAddress>> addresses({String? after}) async {
    final data = await _graphql(_addressesQuery, {'after': after});
    final customer = data['customer'] as Map<String, dynamic>;
    final defaultAddress = customer['defaultAddress'] as Map<String, dynamic>?;
    final addresses = customer['addresses'] as Map<String, dynamic>;
    final pageInfo = addresses['pageInfo'] as Map<String, dynamic>;
    return AccountConnection(
      items: (addresses['nodes'] as List)
          .map(
            (address) => CustomerAddress.fromJson(
              address as Map<String, dynamic>,
              defaultAddressId: defaultAddress?['id'] as String?,
            ),
          )
          .toList(),
      hasNextPage: pageInfo['hasNextPage'] as bool,
      endCursor: pageInfo['endCursor'] as String?,
    );
  }

  Future<void> setDefaultAddress(CustomerAddress address) async {
    final data = await _graphql(_updateAddressMutation, {
      'addressId': address.id,
      'address': address.input,
    });
    final payload = data['customerAddressUpdate'] as Map<String, dynamic>;
    final errors = payload['userErrors'] as List;
    if (errors.isNotEmpty) {
      throw Exception(
        errors
            .map((error) => (error as Map<String, dynamic>)['message'])
            .join('\n'),
      );
    }
  }

  Future<CustomerAccount> updateProfile({
    required String firstName,
    required String lastName,
  }) async {
    final data = await _graphql(_updateCustomerMutation, {
      'input': {'firstName': firstName, 'lastName': lastName},
    });
    final payload = data['customerUpdate'] as Map<String, dynamic>;
    final errors = payload['userErrors'] as List;
    if (errors.isNotEmpty) {
      throw Exception(
        errors
            .map((error) => (error as Map<String, dynamic>)['message'])
            .join('\n'),
      );
    }
    return CustomerAccount.fromJson(
      payload['customer'] as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> _graphql(
    String query, [
    Map<String, dynamic> variables = const {},
  ]) async {
    final endpoint = await _apiUrl();
    final response = await _authorized(
      (token) => http.post(
        endpoint,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': token,
        },
        body: jsonEncode({'query': query, 'variables': variables}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Shopify Customer Account API request failed (${response.statusCode})',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final errors = body['errors'] as List?;
    if (errors?.isNotEmpty == true) {
      throw Exception(
        errors!
            .map((error) => (error as Map<String, dynamic>)['message'])
            .join('\n'),
      );
    }
    return body['data'] as Map<String, dynamic>;
  }

  Future<Uri> _apiUrl() async {
    final request = _endpoint ??= _discoverApiUrl();
    try {
      return await request;
    } catch (_) {
      if (identical(_endpoint, request)) _endpoint = null;
      rethrow;
    }
  }

  Future<Uri> _discoverApiUrl() async {
    final response = await http.get(
      Uri.parse(
        '${ShopifyAuthConfig.storefrontUrl.replaceAll(RegExp(r'/$'), '')}/.well-known/customer-account-api',
      ),
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Could not discover Shopify Customer Account API.');
    }
    final value =
        (jsonDecode(response.body) as Map<String, dynamic>)['graphql_api'];
    final endpoint = value is String ? Uri.tryParse(value) : null;
    if (endpoint == null || endpoint.scheme != 'https') {
      throw Exception('Shopify returned an invalid Customer Account API URL.');
    }
    return endpoint;
  }

  Future<http.Response> _authorized(
    Future<http.Response> Function(String token) send,
  ) async {
    final token = await auth.accessToken();
    var response = await send(token);
    if (response.statusCode == 401) {
      response = await send(await auth.renewAccessToken(token));
      if (response.statusCode == 401) {
        await auth.clearSession();
        throw const AuthenticationExpiredException();
      }
    }
    return response;
  }
}
